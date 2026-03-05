import Foundation
import SwiftUI

/// Navigation state for the menu bar popover
enum MenuViewState: Equatable {
    case notebooks
    case noteStream(Notebook)
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var user: User?
    @Published var notebooks: [Notebook] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var viewState: MenuViewState = .notebooks
    @Published var isCheckingAuth = true

    @AppStorage("defaultNotebookId") var defaultNotebookId: String = ""

    var isAuthenticated: Bool {
        user != nil
    }

    var defaultNotebook: Notebook? {
        guard let uuid = UUID(uuidString: defaultNotebookId) else { return nil }
        return notebooks.first { $0.id == uuid }
    }

    init() {
        if AuthService.shared.isAuthenticated {
            Task {
                await loadUser()
                isCheckingAuth = false
            }
        } else {
            isCheckingAuth = false
        }
    }

    func loadUser() async {
        isLoading = true
        error = nil

        do {
            // Proactively refresh token if needed before making requests
            try await APIService.shared.refreshAccessTokenIfNeeded()

            user = try await AuthService.shared.getMe()
            await loadNotebooks()
        } catch {
            if case APIError.unauthorized = error {
                AuthService.shared.logout()
                user = nil
            }
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadNotebooks() async {
        do {
            let allNotebooks: [Notebook] = try await APIService.shared.get("notebooks")
            notebooks = allNotebooks.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }

            // Set default notebook if not set
            if defaultNotebookId.isEmpty, let first = notebooks.first {
                defaultNotebookId = first.id.uuidString
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            user = try await AuthService.shared.login(email: email, password: password)
            await loadNotebooks()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        AuthService.shared.logout()
        user = nil
        notebooks = []
        defaultNotebookId = ""
        viewState = .notebooks
    }

    // MARK: - Navigation

    func openNoteStream(for notebook: Notebook) {
        viewState = .noteStream(notebook)
    }

    func backToNotebooks() {
        viewState = .notebooks
    }
}
