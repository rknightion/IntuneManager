import Foundation

actor GraphAPIClient {
    static let shared = GraphAPIClient()

    private let baseURL = "https://graph.microsoft.com/beta"
    private let session: URLSession
    private nonisolated let decoder: JSONDecoder
    private nonisolated let encoder: JSONEncoder
    private let rateLimiter = RateLimiter.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 5

        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    // MARK: - Generic Request Methods

    func get<T: Decodable & Sendable>(_ endpoint: String,
                            parameters: [String: String]? = nil,
                            headers: [String: String]? = nil) async throws -> T {
        let request = try await buildRequest(
            endpoint: endpoint,
            method: "GET",
            parameters: parameters,
            headers: headers
        )
        return try await performRequest(request)
    }

    func post<T: Encodable, R: Decodable & Sendable>(_ endpoint: String,
                                           body: T,
                                           headers: [String: String]? = nil) async throws -> R {
        let request = try await buildRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            headers: headers
        )
        return try await performRequest(request)
    }

    func patch<T: Encodable, R: Decodable & Sendable>(_ endpoint: String,
                                            body: T,
                                            headers: [String: String]? = nil) async throws -> R {
        let request = try await buildRequest(
            endpoint: endpoint,
            method: "PATCH",
            body: body,
            headers: headers
        )
        return try await performRequest(request)
    }

    func delete(_ endpoint: String,
                headers: [String: String]? = nil) async throws {
        let request = try await buildRequest(
            endpoint: endpoint,
            method: "DELETE",
            headers: headers
        )
        let _: EmptyResponse = try await performRequest(request)
    }

    // MARK: - Batch Operations

    func batch<T: Decodable & Sendable>(_ requests: [BatchRequest]) async throws -> [BatchResponse<T>] {
        // Split into rate-limited batches
        let batches = await rateLimiter.splitIntoBatches(requests, isWriteOperation: true)
        var allResponses: [BatchResponse<T>] = []

        for (index, batch) in batches.enumerated() {
            if index > 0 {
                // Add delay between batches to avoid rate limits
                let delaySeconds = 1.0
                await MainActor.run {
                    Logger.shared.info("Delaying \(delaySeconds)s between batch \(index) and \(index + 1)", category: .network)
                }
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }

            let batchBody = BatchRequestBody(requests: batch)
            let batchEndpoint = "/$batch"

            let request = try await buildRequest(
                endpoint: batchEndpoint,
                method: "POST",
                body: batchBody
            )

            let batchResponseBody: BatchResponseBody<T> = try await performRequest(request)

            // Check for individual 429s in the batch
            let failedRequests = batchResponseBody.responses.filter { $0.status == 429 }
            if !failedRequests.isEmpty {
                await MainActor.run {
                    Logger.shared.warning("Batch contained \(failedRequests.count) rate-limited requests", category: .network)
                }
                await rateLimiter.recordRateLimit()

                // Retry failed requests after delay
                if failedRequests.count < batch.count {
                    // Some succeeded, keep those
                    let successfulResponses = batchResponseBody.responses.filter { $0.status != 429 }
                    allResponses.append(contentsOf: successfulResponses)
                }

                // Retry the failed requests
                let failedRequestIds = Set(failedRequests.map { $0.id })
                let requestsToRetry = batch.filter { failedRequestIds.contains($0.id) }

                if !requestsToRetry.isEmpty {
                    await MainActor.run {
                        Logger.shared.info("Retrying \(requestsToRetry.count) rate-limited requests", category: .network)
                    }
                    let retryDelay = await rateLimiter.calculateRetryDelay(attemptNumber: 1, retryAfterHeader: nil)
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))

                    // Retry with smaller batch size
                    let retryBatchBody = BatchRequestBody(requests: requestsToRetry)
                    let retryRequest = try await buildRequest(
                        endpoint: "/$batch",
                        method: "POST",
                        body: retryBatchBody
                    )
                    let retryResponseBody: BatchResponseBody<T> = try await performRequest(retryRequest)
                    allResponses.append(contentsOf: retryResponseBody.responses)
                }
            } else {
                allResponses.append(contentsOf: batchResponseBody.responses)
            }
        }

        return allResponses
    }

    // MARK: - Pagination Support

    func getAllPages<T: Decodable & Sendable>(_ endpoint: String,
                                   parameters: [String: String]? = nil,
                                   headers: [String: String]? = nil) async throws -> [T] {
        var results: [T] = []
        var nextLink: String? = endpoint
        var currentParams = parameters
        var pageCount = 0

        await MainActor.run {
            Logger.shared.info("Starting paginated request for: \(endpoint)", category: .network)
        }

        while let link = nextLink {
            pageCount += 1
            let currentPage = pageCount
            await MainActor.run {
                Logger.shared.info("Fetching page \(currentPage) from: \(link)", category: .network)
            }

            let request = try await buildRequest(
                endpoint: link,
                method: "GET",
                parameters: currentParams,
                headers: headers
            )

            let response: GraphResponse<T> = try await performRequest(request)
            if let value = response.value {
                let currentPage = pageCount
                let itemCount = value.count
                await MainActor.run {
                    Logger.shared.info("Page \(currentPage) returned \(itemCount) items", category: .network)
                }
                results.append(contentsOf: value)
            } else {
                let currentPage = pageCount
                await MainActor.run {
                    Logger.shared.warning("Page \(currentPage) returned no items", category: .network)
                }
            }

            if let next = response.nextLink {
                await MainActor.run {
                    Logger.shared.info("Next page link found: \(next)", category: .network)
                }
                nextLink = next
            } else {
                await MainActor.run {
                    Logger.shared.info("No more pages - pagination complete", category: .network)
                }
                nextLink = nil
            }
            currentParams = nil // Parameters only needed for first request
        }

        let totalPages = pageCount
        let totalItems = results.count
        await MainActor.run {
            Logger.shared.info("Pagination complete: \(totalPages) pages, \(totalItems) total items", category: .network)
        }
        return results
    }

    // MainActor-isolated version for SwiftData models (non-Sendable)
    @MainActor
    func getAllPagesForModels<T: Decodable>(_ endpoint: String,
                                             parameters: [String: String]? = nil,
                                             headers: [String: String]? = nil) async throws -> [T] {
        var results: [T] = []
        var nextLink: String? = endpoint
        var currentParams = parameters
        var pageCount = 0

        await MainActor.run {
            Logger.shared.info("Starting paginated request for: \(endpoint)", category: .network)
        }

        while let link = nextLink {
            pageCount += 1
            let currentPage = pageCount
            await MainActor.run {
                Logger.shared.info("Fetching page \(currentPage) from: \(link)", category: .network)
            }

            let request = try await buildRequest(
                endpoint: link,
                method: "GET",
                parameters: currentParams,
                headers: headers
            )

            let response: GraphModelResponse<T> = try await performModelRequest(request)
            if let value = response.value {
                let currentPage = pageCount
                let itemCount = value.count
                await MainActor.run {
                    Logger.shared.info("Page \(currentPage) returned \(itemCount) items", category: .network)
                }
                results.append(contentsOf: value)
            } else {
                let currentPage = pageCount
                await MainActor.run {
                    Logger.shared.warning("Page \(currentPage) returned no items", category: .network)
                }
            }

            if let next = response.nextLink {
                await MainActor.run {
                    Logger.shared.info("Next page link found: \(next)", category: .network)
                }
                nextLink = next
            } else {
                await MainActor.run {
                    Logger.shared.info("No more pages - pagination complete", category: .network)
                }
                nextLink = nil
            }
            currentParams = nil // Parameters only needed for first request
        }

        let totalPages = pageCount
        let totalItems = results.count
        await MainActor.run {
            Logger.shared.info("Pagination complete: \(totalPages) pages, \(totalItems) total items", category: .network)
        }
        return results
    }

    func getModel<T: Decodable>(_ endpoint: String,
                                 parameters: [String: String]? = nil,
                                 headers: [String: String]? = nil) async throws -> T {
        let request = try await buildRequest(
            endpoint: endpoint,
            method: "GET",
            parameters: parameters,
            headers: headers
        )

        return try await performModelRequest(request)
    }

    func postModel<T: Encodable, R: Decodable>(_ endpoint: String,
                                                body: T,
                                                headers: [String: String]? = nil) async throws -> R {
        let request = try await buildRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            headers: headers
        )

        return try await performModelRequest(request)
    }

    func patchModel<T: Encodable, R: Decodable>(_ endpoint: String,
                                                 body: T,
                                                 headers: [String: String]? = nil) async throws -> R {
        let request = try await buildRequest(
            endpoint: endpoint,
            method: "PATCH",
            body: body,
            headers: headers
        )

        return try await performModelRequest(request)
    }

    @MainActor
    func batchModels<T: Decodable>(_ requests: [BatchRequest]) async throws -> [BatchResponse<T>] {
        // Split into rate-limited batches
        let batches = await rateLimiter.splitIntoBatches(requests, isWriteOperation: true)
        var allResponses: [BatchResponse<T>] = []

        for (index, batch) in batches.enumerated() {
            if index > 0 {
                // Add delay between batches to avoid rate limits
                let delaySeconds = 1.0
                await MainActor.run {
                    Logger.shared.info("Delaying \(delaySeconds)s between batch \(index) and \(index + 1)", category: .network)
                }
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }

            let batchBody = BatchRequestBody(requests: batch)
            let request = try await buildRequest(
                endpoint: "/$batch",
                method: "POST",
                body: batchBody
            )

            let responseBody: BatchResponseBody<T> = try await performModelRequest(request)

            // Check for individual 429s in the batch
            let failedRequests = responseBody.responses.filter { $0.status == 429 }
            if !failedRequests.isEmpty {
                await MainActor.run {
                    Logger.shared.warning("Batch contained \(failedRequests.count) rate-limited requests", category: .network)
                }
                await rateLimiter.recordRateLimit()

                // Keep successful responses
                let successfulResponses = responseBody.responses.filter { $0.status != 429 }
                allResponses.append(contentsOf: successfulResponses)

                // Retry failed requests after delay
                let failedRequestIds = Set(failedRequests.map { $0.id })
                let requestsToRetry = batch.filter { failedRequestIds.contains($0.id) }

                if !requestsToRetry.isEmpty {
                    await MainActor.run {
                        Logger.shared.info("Retrying \(requestsToRetry.count) rate-limited requests", category: .network)
                    }
                    let retryDelay = await rateLimiter.calculateRetryDelay(attemptNumber: 1, retryAfterHeader: nil)
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))

                    let retryResponses: [BatchResponse<T>] = try await batchModels(requestsToRetry)
                    allResponses.append(contentsOf: retryResponses)
                }
            } else {
                allResponses.append(contentsOf: responseBody.responses)
            }
        }

        return allResponses
    }

    // MARK: - Public Helper Methods for Special Cases

    func buildCountRequest(endpoint: String,
                           headers: [String: String]? = nil) async throws -> URLRequest {
        return try await buildRequest(
            endpoint: endpoint,
            method: "GET",
            parameters: nil,
            headers: headers
        )
    }

    func performRawRequest(_ request: URLRequest) async throws -> Data {
        return try await performDataRequest(request)
    }

    /// Get current rate limit status for monitoring
    func getRateLimitStatus() async -> (total: Int, write: Int, maxTotal: Int, maxWrite: Int) {
        return await rateLimiter.getRateLimitStatus()
    }

    /// Log current rate limit status
    func logRateLimitStatus() async {
        let status = await getRateLimitStatus()
        let totalPercentage = Double(status.total) / Double(status.maxTotal) * 100
        let writePercentage = Double(status.write) / Double(status.maxWrite) * 100

        await MainActor.run {
            Logger.shared.info("Rate Limit Status - Total: \(status.total)/\(status.maxTotal) (\(String(format: "%.1f", totalPercentage))%), Write: \(status.write)/\(status.maxWrite) (\(String(format: "%.1f", writePercentage))%)", category: .network)
        }
    }

    // MARK: - Private Methods

    private func buildRequest<T: Encodable>(endpoint: String,
                                             method: String,
                                             parameters: [String: String]? = nil,
                                             body: T? = nil,
                                             headers: [String: String]? = nil) async throws -> URLRequest {
        // Build URL
        var urlString = endpoint.starts(with: "http") ? endpoint : "\(baseURL)\(endpoint)"

        if let parameters = parameters {
            var components = URLComponents(string: urlString)!
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components.url!.absoluteString
        }

        guard let url = URL(string: urlString) else {
            throw GraphAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add authorization header
        do {
            let token = try await AuthManagerV2.shared.getAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch let authError as AuthError {
            throw GraphAPIError.authenticationFailed(authError)
        } catch {
            throw GraphAPIError.networkError(error)
        }

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body if present
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw GraphAPIError.encodingFailed(error)
            }
        }

        return request
    }

    private func buildRequest(endpoint: String,
                             method: String,
                             parameters: [String: String]? = nil,
                             headers: [String: String]? = nil) async throws -> URLRequest {
        let emptyBody: EmptyBody? = nil
        return try await buildRequest(
            endpoint: endpoint,
            method: method,
            parameters: parameters,
            body: emptyBody,
            headers: headers
        )
    }

    private func performDataRequest(_ request: URLRequest, attemptNumber: Int = 1) async throws -> Data {
        // Check if this is a write operation
        let isWriteOperation = ["POST", "PUT", "PATCH", "DELETE"].contains(request.httpMethod ?? "GET")

        // Apply rate limiting delay if needed
        let delay = await rateLimiter.calculateDelay(isWriteOperation: isWriteOperation)
        if delay > 0 {
            await MainActor.run {
                Logger.shared.info("Rate limit prevention: delaying request by \(String(format: "%.2f", delay)) seconds", category: .network)
            }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Check if we can make the request
        if !(await rateLimiter.canMakeRequest(isWriteOperation: isWriteOperation)) {
            await MainActor.run {
                Logger.shared.warning("Preemptively throttling request to avoid rate limit", category: .network)
            }
            // Wait and retry
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            return try await performDataRequest(request, attemptNumber: attemptNumber)
        }

        // Record the request
        await rateLimiter.recordRequest(isWriteOperation: isWriteOperation)

        // Log the outgoing request
        if attemptNumber > 1 {
            await MainActor.run {
                Logger.shared.info("→ Retry attempt \(attemptNumber) for \(request.httpMethod ?? "?") \(request.url?.path ?? "")", category: .network)
            }
        } else {
            await MainActor.run {
                Logger.shared.logNetworkRequest(request)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    Logger.shared.error("Invalid response - not HTTP", category: .network)
                }
                throw GraphAPIError.invalidResponse
            }

            // Log the response
            await MainActor.run {
                Logger.shared.info("← Response: \(httpResponse.statusCode) from \(request.url?.path ?? "")", category: .network)
            }

            switch httpResponse.statusCode {
            case 200...299:
                // Reset rate limit tracking on successful request
                await rateLimiter.resetRateLimitTracking()
                return data

            case 401:
                await MainActor.run {
                    Logger.shared.error("Unauthorized (401) - Token may be expired", category: .network)
                }
                throw GraphAPIError.unauthorized

            case 403:
                await MainActor.run {
                    Logger.shared.error("Forbidden (403) - Insufficient permissions", category: .network)
                }
                throw GraphAPIError.forbidden

            case 404:
                await MainActor.run {
                    Logger.shared.warning("Not Found (404) - Resource doesn't exist", category: .network)
                }
                throw GraphAPIError.notFound

            case 429:
                // Rate limiting - extract retry after header
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                await MainActor.run {
                    Logger.shared.warning("Rate Limited (429) - Retry after: \(retryAfter ?? "unknown")", category: .network)
                }

                // Record the rate limit
                await rateLimiter.recordRateLimit()

                // Check if we should retry
                let error = GraphAPIError.rateLimited(retryAfter: retryAfter)
                if await rateLimiter.shouldRetry(attemptNumber: attemptNumber, error: error) {
                    let retryDelay = await rateLimiter.calculateRetryDelay(attemptNumber: attemptNumber, retryAfterHeader: retryAfter)
                    await MainActor.run {
                        Logger.shared.info("Will retry after \(String(format: "%.2f", retryDelay)) seconds", category: .network)
                    }
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    return try await performDataRequest(request, attemptNumber: attemptNumber + 1)
                }
                throw error

            default:
                if let errorResponse = try? decoder.decode(GraphErrorResponse.self, from: data) {
                    await MainActor.run {
                        Logger.shared.error("API Error (\(httpResponse.statusCode)): \(errorResponse.error.message) (Code: \(errorResponse.error.code))", category: .network)
                    }
                    throw GraphAPIError.serverError(message: errorResponse.error.message, code: errorResponse.error.code)
                }
                await MainActor.run {
                    Logger.shared.error("HTTP Error: \(httpResponse.statusCode)", category: .network)
                }
                throw GraphAPIError.httpError(statusCode: httpResponse.statusCode)
            }
        } catch let error as GraphAPIError {
            // For network errors, consider retrying
            if case .networkError = error,
               await rateLimiter.shouldRetry(attemptNumber: attemptNumber, error: error) {
                let retryDelay = await rateLimiter.calculateRetryDelay(attemptNumber: attemptNumber, retryAfterHeader: nil)
                await MainActor.run {
                    Logger.shared.info("Network error, will retry after \(String(format: "%.2f", retryDelay)) seconds", category: .network)
                }
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                return try await performDataRequest(request, attemptNumber: attemptNumber + 1)
            }
            throw error
        } catch {
            // Check if we should retry for other errors
            let graphError = GraphAPIError.networkError(error)
            if await rateLimiter.shouldRetry(attemptNumber: attemptNumber, error: graphError) {
                let retryDelay = await rateLimiter.calculateRetryDelay(attemptNumber: attemptNumber, retryAfterHeader: nil)
                await MainActor.run {
                    Logger.shared.info("Error occurred, will retry after \(String(format: "%.2f", retryDelay)) seconds", category: .network)
                }
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                return try await performDataRequest(request, attemptNumber: attemptNumber + 1)
            }
            throw GraphAPIError.networkError(error)
        }
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await performDataRequest(request)

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        return try decoder.decode(T.self, from: data)
    }

    @MainActor
    private func performModelRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await performDataRequest(request)

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        let modelDecoder = JSONDecoder()
        modelDecoder.dateDecodingStrategy = .iso8601
        return try modelDecoder.decode(T.self, from: data)
    }
}

// MARK: - Supporting Types

struct GraphResponse<T: Decodable & Sendable>: Decodable, Sendable {
    nonisolated let value: [T]?
    nonisolated let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

struct GraphModelResponse<T: Decodable>: Decodable {
    nonisolated let value: [T]?
    nonisolated let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

struct GraphErrorResponse: Decodable, Sendable {
    nonisolated let error: GraphError

    struct GraphError: Decodable, Sendable {
        nonisolated let code: String
        nonisolated let message: String
        nonisolated let innerError: InnerError?

        struct InnerError: Decodable, Sendable {
            nonisolated let requestId: String?
            nonisolated let date: String?
        }
    }
}

struct BatchRequest: Encodable, Sendable {
    nonisolated let id: String
    nonisolated let method: String
    nonisolated let url: String
    nonisolated let body: Data?
    nonisolated let headers: [String: String]?

    nonisolated init(id: String = UUID().uuidString,
         method: String,
         url: String,
         body: Encodable? = nil,
         headers: [String: String]? = nil) {
        self.id = id
        self.method = method
        self.url = url
        if let body = body {
            self.body = try? JSONEncoder().encode(body)
        } else {
            self.body = nil
        }
        self.headers = headers
    }
}

struct BatchRequestBody: Encodable, Sendable {
    nonisolated let requests: [BatchRequest]
}

struct BatchResponse<T: Decodable>: Decodable {
    nonisolated let id: String
    nonisolated let status: Int
    nonisolated let body: T?
    nonisolated let headers: [String: String]?
}

struct BatchResponseBody<T: Decodable>: Decodable {
    nonisolated let responses: [BatchResponse<T>]
}

struct EmptyBody: Encodable, Sendable {}

struct EmptyResponse: Decodable, Sendable {
    nonisolated init() {}
}

extension BatchResponse: Sendable where T: Sendable {}
extension BatchResponseBody: Sendable where T: Sendable {}

// MARK: - Error Types

enum GraphAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: String?)
    case serverError(message: String, code: String)
    case httpError(statusCode: Int)
    case networkError(Error)
    case authenticationFailed(AuthError)
    case encodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .forbidden:
            return "Access forbidden. You don't have permission for this operation."
        case .notFound:
            return "Resource not found"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter ?? "unknown") seconds"
        case .serverError(let message, let code):
            return "Server error (\(code)): \(message)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed(let authError):
            return authError.localizedDescription
        case .encodingFailed(let error):
            return "Failed to encode request body: \(error.localizedDescription)"
        }
    }
}
