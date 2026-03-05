import Foundation

final class APIService {
    static let shared = APIService()

    private static let apiURLKey = "apiURL"
    #if DEBUG
    private static let defaultAPIURL = "http://localhost:8080/api"
    #else
    private static let defaultAPIURL = "https://api.noted.app/api"
    #endif

    var baseURL: URL {
        let urlString = UserDefaults.standard.string(forKey: Self.apiURLKey) ?? Self.defaultAPIURL
        return URL(string: urlString) ?? URL(string: Self.defaultAPIURL)!
    }

    static var apiURL: String {
        get { UserDefaults.standard.string(forKey: apiURLKey) ?? defaultAPIURL }
        set { UserDefaults.standard.set(newValue, forKey: apiURLKey) }
    }

    static var defaultURL: String { defaultAPIURL }

    /// Check if currently online (reads from NetworkMonitor)
    /// Note: This is a best-effort check; actual requests may still fail due to network conditions
    @MainActor
    var isOnline: Bool {
        NetworkMonitor.shared.isConnected
    }

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

    private let refreshThresholdDays: TimeInterval = 7
    private var refreshTask: Task<Void, Error>?
    private let refreshLock = NSLock()

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

    func tokenExpirationDate(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        // Convert URL-safe base64 to standard base64
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let payloadData = Data(base64Encoded: base64) else { return nil }
        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else { return nil }
        guard let exp = payload["exp"] as? TimeInterval else { return nil }

        return Date(timeIntervalSince1970: exp)
    }

    func accessTokenNeedsRefresh() -> Bool {
        guard let token = accessToken,
              let expirationDate = tokenExpirationDate(token) else {
            return false
        }

        // Refresh if token expires within threshold OR is already expired
        let threshold = Date().addingTimeInterval(refreshThresholdDays * 24 * 60 * 60)
        return expirationDate < threshold
    }

    /// Returns true if the access token is already expired
    func isAccessTokenExpired() -> Bool {
        guard let token = accessToken,
              let expirationDate = tokenExpirationDate(token) else {
            return true // No token = treat as expired
        }
        return expirationDate < Date()
    }

    func refreshAccessTokenIfNeeded() async throws {
        guard accessTokenNeedsRefresh(),
              let currentRefreshToken = refreshToken else {
            return
        }

        // Check if there's already a refresh in progress
        let existingTask: Task<Void, Error>? = refreshLock.withLock {
            if let task = refreshTask {
                return task
            }
            return nil
        }

        // If another refresh is in progress, wait for it
        if let existingTask = existingTask {
            try await existingTask.value
            return
        }

        // Create a new refresh task
        let task = Task<Void, Error> {
            defer {
                refreshLock.withLock {
                    refreshTask = nil
                }
            }

            // Double-check after acquiring the lock
            guard accessTokenNeedsRefresh() else { return }

            let response: TokenRefreshResponse = try await refreshTokenRequest(currentRefreshToken)
            setTokens(access: response.accessToken, refresh: response.refreshToken)
        }

        refreshLock.withLock {
            refreshTask = task
        }

        try await task.value
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

struct Empty: Codable {}

// MARK: - Image Upload

extension APIService {
    func uploadImage(_ imageData: Data, filename: String, noteId: UUID, keepFullSize: Bool) async throws -> NoteImage {
        try? await refreshAccessTokenIfNeeded()

        guard let token = accessToken else {
            throw APIError.unauthorized
        }

        let boundary = UUID().uuidString
        let url = baseURL.appendingPathComponent("images")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build multipart body
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"note_id\"\r\n\r\n")
        body.appendString("\(noteId.uuidString)\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"keep_full_size\"\r\n\r\n")
        body.appendString("\(keepFullSize)\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        return try decoder.decode(NoteImage.self, from: data)
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Notes API

extension APIService {
    /// Fetches all notes for a notebook
    /// - Parameter notebookId: The notebook UUID
    /// - Returns: Array of notes sorted by creation date (newest first)
    func getNotes(notebookId: UUID) async throws -> [Note] {
        let notes: [Note] = try await get("notebooks/\(notebookId.uuidString)/notes")
        return notes
            .filter { $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Fetches notes updated since a given date
    /// - Parameter since: The date to fetch updates from
    /// - Returns: Array of notes updated since the given date (including deleted)
    func getNotesUpdatedSince(_ since: Date) async throws -> [Note] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = formatter.string(from: since)
        guard let encodedSince = sinceString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidResponse
        }
        return try await get("notes?since=\(encodedSince)")
    }

    /// Fetches all images for a note
    /// - Parameter noteId: The note UUID
    /// - Returns: Array of note images
    func getNoteImages(noteId: UUID) async throws -> [NoteImage] {
        try await get("notes/\(noteId.uuidString)/images")
    }

    /// Updates an existing note
    /// - Parameters:
    ///   - noteId: The note UUID
    ///   - plainText: New plain text content
    ///   - isTodo: Whether the note is a todo
    ///   - isDone: Whether the todo is done
    /// - Returns: Updated note
    func updateNote(noteId: UUID, plainText: String, isTodo: Bool? = nil, isDone: Bool? = nil) async throws -> Note {
        struct UpdateRequest: Encodable {
            let plainText: String
            let isTodo: Bool?
            let isDone: Bool?

            enum CodingKeys: String, CodingKey {
                case plainText = "plain_text"
                case isTodo = "is_todo"
                case isDone = "is_done"
            }
        }

        let request = UpdateRequest(plainText: plainText, isTodo: isTodo, isDone: isDone)
        return try await put("notes/\(noteId.uuidString)", body: request)
    }

    /// Deletes a note
    /// - Parameter noteId: The note UUID
    func deleteNote(noteId: UUID) async throws {
        try await delete("notes/\(noteId.uuidString)")
    }
}
