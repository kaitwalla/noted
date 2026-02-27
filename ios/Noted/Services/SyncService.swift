import Foundation

final class SyncService {
    static let shared = SyncService()

    private let api = APIService.shared
    private let localData = LocalDataService.shared

    private let lastSyncKey = "lastSyncTime"

    var lastSyncTime: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }

    var isSyncing = false

    private init() {}

    // MARK: - Main Sync

    @MainActor
    func sync() async throws {
        guard !isSyncing else { return }
        guard api.isAuthenticated else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // 1. Pull remote changes
            let remoteChanges = try await pullChanges()

            // 2. Merge remote changes into local
            mergeRemoteChanges(remoteChanges)

            // 3. Get pending local changes
            let pendingChanges = localData.getPendingChanges()

            // 4. Push local changes if any
            if !pendingChanges.isEmpty {
                try await pushChanges(pendingChanges)
            }

            // 5. Update last sync time
            lastSyncTime = Date()

        } catch {
            print("Sync failed: \(error)")
            throw error
        }
    }

    // MARK: - Pull Changes

    private func pullChanges() async throws -> SyncResponse {
        var path = "sync"
        if let since = lastSyncTime {
            let formatter = ISO8601DateFormatter()
            path += "?since=\(formatter.string(from: since))"
        }

        return try await api.get(path)
    }

    // MARK: - Push Changes

    private func pushChanges(_ changes: PendingChanges) async throws {
        let allNotebooks = changes.createdNotebooks + changes.updatedNotebooks
        let allNotes = changes.createdNotes + changes.updatedNotes

        let request = SyncRequest(
            notebooks: allNotebooks,
            notes: allNotes,
            deletedNotebookIds: changes.deletedNotebookIds,
            deletedNoteIds: changes.deletedNoteIds
        )

        let response: SyncResponse = try await api.post("sync", body: request)

        // Mark successfully synced items
        let syncedNotebookIds = allNotebooks.map { $0.id } + changes.deletedNotebookIds
        let syncedNoteIds = allNotes.map { $0.id } + changes.deletedNoteIds

        localData.markAsSynced(notebookIds: syncedNotebookIds, noteIds: syncedNoteIds)

        // Remove permanently deleted items
        localData.removeDeletedItems(
            notebookIds: changes.deletedNotebookIds,
            noteIds: changes.deletedNoteIds
        )

        // Merge any additional changes from server response
        mergeRemoteChanges(response)
    }

    // MARK: - Merge

    private func mergeRemoteChanges(_ response: SyncResponse) {
        // Merge notebooks
        localData.mergeRemoteNotebooks(response.notebooks)

        // Merge notes
        localData.mergeRemoteNotes(response.notes)

        // Remove deleted items
        localData.removeDeletedItems(
            notebookIds: response.deletedNotebookIds,
            noteIds: response.deletedNoteIds
        )
    }

    // MARK: - Initial Load

    @MainActor
    func initialLoad() async throws {
        // For initial load, fetch all data from server
        let notebooks: [Notebook] = try await api.get("notebooks")
        localData.mergeRemoteNotebooks(notebooks)

        // Fetch notes for each notebook
        for notebook in notebooks {
            let notes: [Note] = try await api.get("notebooks/\(notebook.id)/notes")
            localData.mergeRemoteNotes(notes)
        }

        lastSyncTime = Date()
    }

    // MARK: - Clear

    func clearSyncData() {
        lastSyncTime = nil
        localData.clearAllData()
    }
}
