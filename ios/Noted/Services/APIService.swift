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

    /// How many days before expiration to trigger automatic refresh
    private let refreshThresholdDays: TimeInterval = 7

    /// Lock to prevent concurrent refresh attempts
    private let refreshLock = NSLock()
    private var isRefreshing = false

    private init() {}

    // MARK: - Auth Tokens

    var accessToken: String? {
        get { KeychainService.shared.getAccessToken() }
        set {
            if let token = newValue {
                try? KeychainService.shared.saveAccessToken(token)
            } else {
                try? KeychainService.shared.deleteAccessToken()
            }
        }
    }

    var refreshToken: String? {
        get { KeychainService.shared.getRefreshToken() }
        set {
            if let token = newValue {
                try? KeychainService.shared.saveRefreshToken(token)
            } else {
                try? KeychainService.shared.deleteRefreshToken()
            }
        }
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    func setTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
    }

    func clearTokens() {
        try? KeychainService.shared.deleteAllTokens()
    }

    // MARK: - Token Expiration

    /// Returns the expiration date of a JWT token, or nil if it can't be parsed
    func tokenExpirationDate(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        // Decode the payload (second part)
        var base64 = String(parts[1])
        // Add padding if needed for base64 decoding
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let payloadData = Data(base64Encoded: base64) else { return nil }
        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else { return nil }
        guard let exp = payload["exp"] as? TimeInterval else { return nil }

        return Date(timeIntervalSince1970: exp)
    }

    /// Returns true if the access token will expire within the threshold (7 days)
    func accessTokenNeedsRefresh() -> Bool {
        guard let token = accessToken,
              let expirationDate = tokenExpirationDate(token) else {
            return false
        }

        let threshold = Date().addingTimeInterval(refreshThresholdDays * 24 * 60 * 60)
        return expirationDate < threshold
    }

    /// Attempts to refresh the access token if it's close to expiring
    func refreshAccessTokenIfNeeded() async throws {
        guard accessTokenNeedsRefresh(),
              let currentRefreshToken = refreshToken else {
            return
        }

        // Prevent concurrent refresh attempts
        refreshLock.lock()
        if isRefreshing {
            refreshLock.unlock()
            return
        }
        isRefreshing = true
        refreshLock.unlock()

        defer {
            refreshLock.lock()
            isRefreshing = false
            refreshLock.unlock()
        }

        // Double-check after acquiring lock
        guard accessTokenNeedsRefresh() else { return }

        let response: TokenRefreshResponse = try await refreshTokenRequest(currentRefreshToken)
        setTokens(access: response.accessToken, refresh: response.refreshToken)
    }

    private func refreshTokenRequest(_ token: String) async throws -> TokenRefreshResponse {
        let url = baseURL.appendingPathComponent("auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(RefreshRequest(refreshToken: token))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // If refresh fails, clear tokens to force re-login
            if httpResponse.statusCode == 401 {
                clearTokens()
            }
            throw APIError.unauthorized
        }

        return try decoder.decode(TokenRefreshResponse.self, from: data)
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
        // Automatically refresh token if it's within 7 days of expiration
        // Skip refresh check for auth endpoints to avoid infinite loops
        if !path.hasPrefix("auth/") {
            try? await refreshAccessTokenIfNeeded()
        }

        let url = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
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

// MARK: - Token Refresh Types

private struct RefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

// Empty type for requests/responses with no body
struct Empty: Codable {}
