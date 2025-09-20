import Foundation

actor GraphAPIClient {
    static let shared = GraphAPIClient()

    private let baseURL = "https://graph.microsoft.com/beta"
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 5

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Generic Request Methods

    func get<T: Decodable>(_ endpoint: String,
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

    func post<T: Encodable, R: Decodable>(_ endpoint: String,
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

    func patch<T: Encodable, R: Decodable>(_ endpoint: String,
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

    func batch<T: Decodable>(_ requests: [BatchRequest]) async throws -> [BatchResponse<T>] {
        let batchBody = BatchRequestBody(requests: requests)
        let batchEndpoint = "/$batch"

        let request = try await buildRequest(
            endpoint: batchEndpoint,
            method: "POST",
            body: batchBody
        )

        let batchResponseBody: BatchResponseBody<T> = try await performRequest(request)
        return batchResponseBody.responses
    }

    // MARK: - Pagination Support

    func getAllPages<T: Decodable & Sendable>(_ endpoint: String,
                                   parameters: [String: String]? = nil,
                                   headers: [String: String]? = nil) async throws -> [T] {
        var items: [T] = []
        let sequence: GraphPageSequence<T> = pageSequence(endpoint, parameters: parameters, headers: headers)
        for try await item in sequence {
            items.append(item)
        }
        return items
    }

    // MainActor-isolated version for SwiftData models (non-Sendable)
    @MainActor
    func getAllPagesForModels<T: Decodable>(_ endpoint: String,
                                             parameters: [String: String]? = nil,
                                             headers: [String: String]? = nil) async throws -> [T] {
        var results: [T] = []
        var nextLink: String? = endpoint
        var currentParams = parameters

        while let link = nextLink {
            let response: GraphResponse<T> = try await get(link,
                                                          parameters: currentParams,
                                                          headers: headers)
            if let value = response.value {
                results.append(contentsOf: value)
            }
            nextLink = response.nextLink
            currentParams = nil // Parameters only needed for first request
        }

        return results
    }

    func pageSequence<T: Decodable & Sendable>(_ endpoint: String,
                                    parameters: [String: String]? = nil,
                                    headers: [String: String]? = nil) -> GraphPageSequence<T> {
        GraphPageSequence(client: self,
                          endpoint: endpoint,
                          initialParameters: parameters,
                          headers: headers)
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
            throw .authenticationFailed(authError)
        } catch {
            throw .networkError(error)
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
                throw .encodingFailed(error)
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

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GraphAPIError.invalidResponse
            }

            // Log response for debugging
            Logger.shared.debug("API Response: \(httpResponse.statusCode) for \(request.url?.absoluteString ?? "")")

            switch httpResponse.statusCode {
            case 200...299:
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                return try decoder.decode(T.self, from: data)

            case 401:
                throw GraphAPIError.unauthorized

            case 403:
                throw GraphAPIError.forbidden

            case 404:
                throw GraphAPIError.notFound

            case 429:
                // Rate limiting - extract retry after header
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                throw GraphAPIError.rateLimited(retryAfter: retryAfter)

            default:
                // Try to decode error response
                if let errorResponse = try? decoder.decode(GraphErrorResponse.self, from: data) {
                    throw GraphAPIError.serverError(message: errorResponse.error.message, code: errorResponse.error.code)
                }
                throw GraphAPIError.httpError(statusCode: httpResponse.statusCode)
            }
        } catch let error as GraphAPIError {
            throw error
        } catch {
            throw GraphAPIError.networkError(error)
        }
    }
}

// MARK: - Async Sequence

struct GraphPageSequence<Element: Decodable & Sendable>: AsyncSequence, Sendable {
    typealias AsyncIterator = AsyncThrowingStream<Element, any Error>.Iterator

    private let stream: AsyncThrowingStream<Element, any Error>

    init(client: GraphAPIClient,
         endpoint: String,
         initialParameters: [String: String]?,
         headers: [String: String]?) {
        stream = AsyncThrowingStream { continuation in
            Task {
                var nextLink: String? = endpoint
                var parameters = initialParameters

                do {
                    while let link = nextLink {
                        let response: GraphResponse<Element> = try await client.get(link,
                                                                                    parameters: parameters,
                                                                                    headers: headers)
                        if let value = response.value {
                            for item in value {
                                continuation.yield(item)
                            }
                        }
                        nextLink = response.nextLink
                        parameters = nil
                    }
                    continuation.finish()
                } catch let error as GraphAPIError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: .networkError(error))
                }
            }
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        stream.makeAsyncIterator()
    }
}

// MARK: - Supporting Types

struct GraphResponse<T: Decodable>: Decodable {
    let value: [T]?
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

struct GraphErrorResponse: Decodable {
    let error: GraphError

    struct GraphError: Decodable {
        let code: String
        let message: String
        let innerError: InnerError?

        struct InnerError: Decodable {
            let requestId: String?
            let date: String?
        }
    }
}

struct BatchRequest: Encodable {
    let id: String
    let method: String
    let url: String
    let body: Data?
    let headers: [String: String]?

    init(id: String = UUID().uuidString,
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

struct BatchRequestBody: Encodable {
    let requests: [BatchRequest]
}

struct BatchResponse<T: Decodable>: Decodable {
    let id: String
    let status: Int
    let body: T?
    let headers: [String: String]?
}

struct BatchResponseBody<T: Decodable>: Decodable {
    let responses: [BatchResponse<T>]
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

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
