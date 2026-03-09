import Foundation
import SwiftUI
import Combine

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

    // Offline support
    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var pendingCount = 0
    @Published var hasConflicts = false

    @AppStorage("defaultNotebookId") var defaultNotebookId: String = ""

    private var cancellables = Set<AnyCancellable>()
    private let dataStore = LocalDataStore.shared
    private let syncService = SyncService.shared

    var isAuthenticated: Bool {
        user != nil
    }

    var defaultNotebook: Notebook? {
        guard let uuid = UUID(uuidString: defaultNotebookId) else { return nil }
        return notebooks.first { $0.id == uuid }
    }

    init() {
        setupOfflineSupport()

        if AuthService.shared.isAuthenticated {
            Task {
                await loadUser()
                isCheckingAuth = false
            }
        } else {
            isCheckingAuth = false
        }
    }

    private func setupOfflineSupport() {
        // Subscribe to network status
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOnline)

        // Subscribe to sync status
        syncService.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSyncing)

        syncService.$pendingCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingCount)

        syncService.$hasConflicts
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasConflicts)

        // Start network monitoring
        NetworkMonitor.shared.start()
    }

    func loadUser() async {
        isLoading = true
        error = nil

        // First load from local storage for instant UI
        loadNotebooksFromLocal()

        // Then try to fetch from server
        do {
            // Proactively refresh token if needed before making requests
            try await APIService.shared.refreshAccessTokenIfNeeded()

            user = try await AuthService.shared.getMe()
            await loadNotebooks()

            // Trigger full sync after authenticated load
            await syncService.syncAll()
        } catch {
            if case APIError.unauthorized = error {
                AuthService.shared.logout()
                user = nil
            } else if !isOnline {
                // Offline - use local user data if available
                // For now, just set a minimal user to allow offline access
                if UserDefaults.standard.string(forKey: "lastUserEmail") != nil {
                    // We're offline but have local data - allow limited access
                    self.error = "Offline mode - some features unavailable"
                }
            } else {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func loadNotebooksFromLocal() {
        do {
            let localNotebooks = try dataStore.fetchNotebooks()
            notebooks = localNotebooks.map { Notebook(from: $0) }

            // Set default notebook if not set
            if defaultNotebookId.isEmpty, let first = notebooks.first {
                defaultNotebookId = first.id.uuidString
            }
        } catch {
            // Silently fail - will load from server
        }
    }

    func loadNotebooks() async {
        // First show local data
        loadNotebooksFromLocal()

        // Then try server
        guard isOnline else { return }

        do {
            let allNotebooks: [Notebook] = try await APIService.shared.get("notebooks")
            let filteredNotebooks = allNotebooks.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }

            // Update UI first (before local save which may fail)
            notebooks = filteredNotebooks

            // Set default notebook if not set
            if defaultNotebookId.isEmpty, let first = notebooks.first {
                defaultNotebookId = first.id.uuidString
            }

            // Save to local storage (non-critical)
            try? dataStore.saveNotebooks(filteredNotebooks)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            user = try await AuthService.shared.login(email: email, password: password)

            // Save email for offline reference
            UserDefaults.standard.set(email, forKey: "lastUserEmail")

            await loadNotebooks()

            // Trigger initial sync
            await syncService.syncAll()
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

        // Clear local data
        try? dataStore.clearAllData()
        ImageCacheService.shared.clearCache()

        UserDefaults.standard.removeObject(forKey: "lastUserEmail")
    }

    // MARK: - Navigation

    func openNoteStream(for notebook: Notebook) {
        viewState = .noteStream(notebook)
    }

    func backToNotebooks() {
        viewState = .notebooks
    }

    // MARK: - Sync

    func triggerSync() async {
        await syncService.syncAll()
    }
}
