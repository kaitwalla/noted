import Foundation

final class AuthService {
    static let shared = AuthService()

    private let api = APIService.shared

    private init() {}

    struct LoginRequest: Codable {
        let email: String
        let password: String
    }

    struct RegisterRequest: Codable {
        let email: String
        let password: String
    }

    struct AuthResponse: Codable {
        let token: String
        let user: User
    }

    func login(email: String, password: String) async throws -> User {
        let request = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await api.post("auth/login", body: request)
        api.authToken = response.token
        return response.user
    }

    func register(email: String, password: String) async throws -> User {
        let request = RegisterRequest(email: email, password: password)
        let response: AuthResponse = try await api.post("auth/register", body: request)
        api.authToken = response.token
        return response.user
    }

    func getMe() async throws -> User {
        try await api.get("auth/me")
    }

    func logout() {
        api.authToken = nil
    }

    var isAuthenticated: Bool {
        api.isAuthenticated
    }
}
