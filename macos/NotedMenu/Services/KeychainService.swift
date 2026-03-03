import Foundation

/// Token storage using UserDefaults (simpler alternative to Keychain)
final class KeychainService {
    static let shared = KeychainService()

    private let accessTokenKey = "com.noted.menu.access_token"
    private let refreshTokenKey = "com.noted.menu.refresh_token"

    private init() {}

    // MARK: - Access Token

    func saveAccessToken(_ token: String) throws {
        UserDefaults.standard.set(token, forKey: accessTokenKey)
    }

    func getAccessToken() -> String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
    }

    func deleteAccessToken() throws {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
    }

    // MARK: - Refresh Token

    func saveRefreshToken(_ token: String) throws {
        UserDefaults.standard.set(token, forKey: refreshTokenKey)
    }

    func getRefreshToken() -> String? {
        UserDefaults.standard.string(forKey: refreshTokenKey)
    }

    func deleteRefreshToken() throws {
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
    }

    // MARK: - Clear All

    func deleteAllTokens() throws {
        try? deleteAccessToken()
        try? deleteRefreshToken()
    }
}
