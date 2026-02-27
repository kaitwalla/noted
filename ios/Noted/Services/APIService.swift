import Foundation

final class APIService {
    static let shared = APIService()

    // Configure this for your environment
    #if DEBUG
    private let baseURL = URL(string: "http://localhost:8080/api")!
    #else
    private let baseURL = URL(string: "https://api.noted.app/api")!
    #endif

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private init() {}

    // MARK: - Auth Token

    var authToken: String? {
        get { KeychainService.shared.getToken() }
        set {
            if let token = newValue {
                try? KeychainService.shared.saveToken(token)
            } else {
                try? KeychainService.shared.deleteToken()
            }
        }
    }

    var isAuthenticated: Bool {
        authToken != nil
    }

    // MARK: - Request Methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "GET", body: nil as Empty?)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request(path, method: "POST", body: body)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request(path, method: "PUT", body: body)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request(path, method: "PATCH", body: body)
    }

    func delete(_ path: String) async throws {
        let _: Empty = try await request(path, method: "DELETE", body: nil as Empty?)
    }

    // MARK: - Private

    private func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: String,
        body: B?
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            if T.self == Empty.self {
                return Empty() as! T
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 400..<500:
            let errorMessage = try? decoder.decode(APIErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage?.error)
        default:
            throw APIError.serverError
        }
    }
}

// Empty type for requests/responses with no body
struct Empty: Codable {}
