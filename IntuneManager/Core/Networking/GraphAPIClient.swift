import Foundation

actor GraphAPIClient {
    static let shared = GraphAPIClient()

    private let baseURL = "https://graph.microsoft.com/beta"
    private let session: URLSession
    private nonisolated let decoder: JSONDecoder
    private nonisolated let encoder: JSONEncoder

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
        var results: [T] = []
        var nextLink: String? = endpoint
        var currentParams = parameters

        while let link = nextLink {
            let request = try await buildRequest(
                endpoint: link,
                method: "GET",
                parameters: currentParams,
                headers: headers
            )

            let response: GraphResponse<T> = try await performRequest(request)
            if let value = response.value {
                results.append(contentsOf: value)
            }
            nextLink = response.nextLink
            currentParams = nil
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

        while let link = nextLink {
            let request = try await buildRequest(
                endpoint: link,
                method: "GET",
                parameters: currentParams,
                headers: headers
            )

            let response: GraphModelResponse<T> = try await performModelRequest(request)
            if let value = response.value {
                results.append(contentsOf: value)
            }
            nextLink = response.nextLink
            currentParams = nil // Parameters only needed for first request
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
        let batchBody = BatchRequestBody(requests: requests)
        let request = try await buildRequest(
            endpoint: "/$batch",
            method: "POST",
            body: batchBody
        )

        let responseBody: BatchResponseBody<T> = try await performModelRequest(request)
        return responseBody.responses
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

    private func performDataRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GraphAPIError.invalidResponse
            }

            await Logger.shared.debug("API Response: \(httpResponse.statusCode) for \(request.url?.absoluteString ?? "")")

            switch httpResponse.statusCode {
            case 200...299:
                return data

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
