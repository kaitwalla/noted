import Foundation
import Observation

@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?

    // Form fields
    var email = ""
    var password = ""
    var confirmPassword = ""

    private let authService = AuthService.shared

    init() {
        // Check if user is already authenticated
        isAuthenticated = authService.isAuthenticated
    }

    @MainActor
    func login() async {
        guard validateLoginForm() else { return }

        isLoading = true
        errorMessage = nil

        do {
            currentUser = try await authService.login(email: email, password: password)
            isAuthenticated = true
            clearForm()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func register() async {
        guard validateRegisterForm() else { return }

        isLoading = true
        errorMessage = nil

        do {
            currentUser = try await authService.register(email: email, password: password)
            isAuthenticated = true
            clearForm()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func checkAuthStatus() async {
        guard authService.isAuthenticated else {
            isAuthenticated = false
            return
        }

        do {
            currentUser = try await authService.getMe()
            isAuthenticated = true
        } catch {
            // Token is invalid, log out
            logout()
        }
    }

    func logout() {
        authService.logout()
        isAuthenticated = false
        currentUser = nil
        clearForm()
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
    }

    private func validateLoginForm() -> Bool {
        errorMessage = nil

        guard !email.isEmpty else {
            errorMessage = "Email is required"
            return false
        }

        guard email.contains("@") else {
            errorMessage = "Please enter a valid email"
            return false
        }

        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return false
        }

        return true
    }

    private func validateRegisterForm() -> Bool {
        guard validateLoginForm() else { return false }

        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return false
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return false
        }

        return true
    }
}
