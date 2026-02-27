import Foundation
import Observation

@Observable
final class NotesViewModel {
    var notes: [Note] = []
    var isLoading = false
    var errorMessage: String?

    let notebookId: UUID

    private let localData = LocalDataService.shared
    private let remoteService = NotesService.shared
    private let syncService = SyncService.shared
    private let networkMonitor = NetworkMonitor.shared

    private var pendingSyncTask: Task<Void, Never>?
    private var syncDebounceTask: Task<Void, Never>?

    init(notebookId: UUID) {
        self.notebookId = notebookId
    }

    deinit {
        pendingSyncTask?.cancel()
        syncDebounceTask?.cancel()
    }

    /// Debounced sync to prevent multiple concurrent sync operations
    private func scheduleSync() {
        guard networkMonitor.isConnected else { return }

        // Cancel any pending debounce
        syncDebounceTask?.cancel()

        syncDebounceTask = Task { @MainActor in
            // Debounce: wait a short time to batch rapid changes
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            // Cancel any existing sync before starting new one
            pendingSyncTask?.cancel()

            pendingSyncTask = Task {
                try? await syncService.sync()
            }
        }
    }

    @MainActor
    func fetchNotes() async {
        isLoading = true
        errorMessage = nil

        // Always load from local first (instant)
        notes = localData.fetchNotes(notebookId: notebookId)

        // Then sync with remote if online
        if networkMonitor.isConnected {
            do {
                try await syncService.sync()
                // Reload from local after sync
                notes = localData.fetchNotes(notebookId: notebookId)
            } catch let error as APIError {
                // Only show error if we have no local data
                if notes.isEmpty {
                    errorMessage = error.errorDescription
                }
            } catch {
                if notes.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }

        isLoading = false
    }

    @MainActor
    func createNote(content: String, isTodo: Bool = false) async {
        _ = await createNoteAndReturn(content: content, isTodo: isTodo)
    }

    @MainActor
    func createNoteAndReturn(content: String, isTodo: Bool = false) async -> Note? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return nil }

        // Create locally first (optimistic)
        guard let note = localData.createNote(notebookId: notebookId, content: trimmedContent, isTodo: isTodo) else {
            return nil
        }

        notes.append(note)
        notes.sort { $0.createdAt < $1.createdAt }

        // Sync in background if online (debounced)
        scheduleSync()

        return note
    }

    @MainActor
    func updateNote(_ id: UUID, content: String) async {
        // Update locally first
        if let updated = localData.updateNote(id: id, content: content) {
            if let index = notes.firstIndex(where: { $0.id == id }) {
                notes[index] = updated
            }
        }

        // Sync in background if online (debounced)
        scheduleSync()
    }

    @MainActor
    func toggleTodo(_ id: UUID) async {
        guard let note = notes.first(where: { $0.id == id }) else { return }

        // Toggle locally first
        if let updated = localData.updateNote(id: id, isDone: !note.isDone) {
            if let index = notes.firstIndex(where: { $0.id == id }) {
                notes[index] = updated
            }
        }

        // Sync in background if online (debounced)
        scheduleSync()
    }

    @MainActor
    func deleteNote(_ id: UUID) async {
        // Delete locally first
        localData.deleteNote(id: id)
        notes.removeAll { $0.id == id }

        // Sync in background if online (debounced)
        scheduleSync()
    }

    func clearError() {
        errorMessage = nil
    }
}
