import Foundation
import Observation

@Observable
final class NotebooksViewModel {
    var notebooks: [Notebook] = []
    var isLoading = false
    var errorMessage: String?

    private let localData = LocalDataService.shared
    private let remoteService = NotebooksService.shared
    private let syncService = SyncService.shared
    private let networkMonitor = NetworkMonitor.shared

    @MainActor
    func fetchNotebooks() async {
        isLoading = true
        errorMessage = nil

        // Always load from local first (instant)
        notebooks = localData.fetchNotebooks()

        // Then sync with remote if online
        if networkMonitor.isConnected {
            do {
                try await syncService.sync()
                // Reload from local after sync
                notebooks = localData.fetchNotebooks()
            } catch let error as APIError {
                // Only show error if we have no local data
                if notebooks.isEmpty {
                    errorMessage = error.errorDescription
                }
            } catch {
                if notebooks.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }

        isLoading = false
    }

    @MainActor
    func createNotebook(title: String) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Notebook title cannot be empty"
            return
        }

        // Create locally first (optimistic)
        if let notebook = localData.createNotebook(title: title) {
            notebooks.append(notebook)
            notebooks.sort { $0.sortOrder < $1.sortOrder }
        }

        // Sync in background if online
        if networkMonitor.isConnected {
            Task {
                try? await syncService.sync()
            }
        }
    }

    @MainActor
    func updateNotebook(_ id: UUID, title: String) async {
        // Update locally first
        if let updated = localData.updateNotebook(id: id, title: title) {
            if let index = notebooks.firstIndex(where: { $0.id == id }) {
                notebooks[index] = updated
            }
        }

        // Sync in background if online
        if networkMonitor.isConnected {
            Task {
                try? await syncService.sync()
            }
        }
    }

    @MainActor
    func deleteNotebook(_ id: UUID) async {
        // Delete locally first
        localData.deleteNotebook(id: id)
        notebooks.removeAll { $0.id == id }

        // Sync in background if online
        if networkMonitor.isConnected {
            Task {
                try? await syncService.sync()
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
