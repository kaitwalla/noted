import Foundation
import Combine

/// Orchestrates synchronization between local storage and the server
@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var pendingCount = 0
    @Published private(set) var hasConflicts = false
    @Published private(set) var lastError: String?

    private var cancellables = Set<AnyCancellable>()
    private let dataStore = LocalDataStore.shared
    private var syncTask: Task<Void, Never>?

    private init() {
        // Subscribe to network restoration
        NetworkMonitor.shared.connectionRestored
            .sink { [weak self] in
                Task { @MainActor in
                    await self?.syncAll()
                }
            }
            .store(in: &cancellables)
    }

    /// Perform a full sync: push pending changes then pull server updates
    func syncAll() async {
        guard NetworkMonitor.shared.isConnected else { return }
        guard !isSyncing else { return }

        isSyncing = true
        lastError = nil

        do {
            try dataStore.setSyncing(true)

            // Push pending changes first
            await pushPendingOperations()

            // Then pull server updates
            await pullServerUpdates()

            // Update sync metadata
            let now = Date()
            try dataStore.updateLastSyncTime(now)
            lastSyncTime = now

            // Update conflict status
            let conflicts = try dataStore.fetchConflictedNotes()
            hasConflicts = !conflicts.isEmpty

            // Update pending count
            pendingCount = try dataStore.getPendingCount()

        } catch {
            lastError = error.localizedDescription
            try? dataStore.setSyncError(error.localizedDescription)
        }

        try? dataStore.setSyncing(false)
        isSyncing = false
    }

    /// Push all pending local changes to the server
    private func pushPendingOperations() async {
        do {
            // Get pending notes sorted by update time (oldest first)
            let pendingNotes = try dataStore.fetchPendingNotes()

            for note in pendingNotes {
                await syncNote(note)
            }

            // Get pending images
            let pendingImages = try dataStore.fetchPendingImages()

            for image in pendingImages {
                await syncImage(image)
            }

            pendingCount = try dataStore.getPendingCount()

        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Sync a single note to the server
    private func syncNote(_ note: LocalNote) async {
        do {
            switch note.syncStatus {
            case .pendingCreate:
                // Create note on server
                let decoder = JSONDecoder()
                let content = try decoder.decode(NoteContent.self, from: note.contentJSON.data(using: .utf8) ?? Data())

                let request = NoteCreateRequest(
                    content: content,
                    plainText: note.plainText,
                    isTodo: note.isTodo,
                    isDone: note.isDone
                )

                let serverNote: Note = try await APIService.shared.post(
                    "notebooks/\(note.notebookId.uuidString)/notes",
                    body: request
                )

                // Update local note with server data
                try dataStore.saveNote(serverNote, syncStatus: .synced)

            case .pendingUpdate:
                // Check for conflicts first
                let serverNotes: [Note] = try await APIService.shared.get(
                    "notebooks/\(note.notebookId.uuidString)/notes"
                )

                if let serverNote = serverNotes.first(where: { $0.id == note.id }) {
                    // Check if server version is newer
                    if serverNote.version != note.serverVersion {
                        // Conflict detected!
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601
                        let serverData = try encoder.encode(serverNote)
                        try dataStore.markNoteConflict(id: note.id, serverData: serverData)
                        hasConflicts = true
                        return
                    }
                }

                // No conflict, push update
                let updatedNote = try await APIService.shared.updateNote(
                    noteId: note.id,
                    plainText: note.plainText,
                    isTodo: note.isTodo,
                    isDone: note.isDone
                )

                // Use the server's response version for accurate sync tracking
                try dataStore.markNoteSynced(id: note.id, serverVersion: updatedNote.version)

            case .pendingDelete:
                // Delete on server
                do {
                    try await APIService.shared.deleteNote(noteId: note.id)
                } catch APIError.notFound {
                    // Already deleted on server, that's fine
                }

                // Hard delete locally
                try dataStore.hardDeleteNote(id: note.id)

            case .synced, .conflict:
                // Nothing to do
                break
            }

        } catch APIError.unauthorized {
            // Auth issue - don't retry
            lastError = "Please log in again"
        } catch {
            // Network or other error - will retry on next sync
            lastError = error.localizedDescription
        }
    }

    /// Sync a single image to the server
    private func syncImage(_ image: LocalNoteImage) async {
        guard image.syncStatus == .pendingCreate else { return }
        guard let localPath = image.localPath else { return }

        do {
            let imageURL = ImageCacheService.shared.getImageURL(localPath: localPath)
            guard let imageData = try? Data(contentsOf: imageURL) else {
                // Image file doesn't exist, skip
                return
            }

            let serverImage = try await APIService.shared.uploadImage(
                imageData,
                filename: image.filename,
                noteId: image.noteId,
                keepFullSize: image.keepFullSize
            )

            // Update local image with server data
            try dataStore.saveNoteImage(serverImage, localPath: localPath)

        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Pull updates from server since last sync
    private func pullServerUpdates() async {
        do {
            // Get last sync time
            let metadata = try dataStore.getSyncMetadata()
            let lastSync = metadata?.lastSyncTime

            // Fetch updated notes
            var path = "notes"
            if let since = lastSync {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let sinceString = formatter.string(from: since)
                path = "notes?since=\(sinceString)"
            }

            let updatedNotes: [Note] = try await APIService.shared.get(path)

            for serverNote in updatedNotes {
                try await processServerNote(serverNote)
            }

            // Also fetch notebooks
            let notebooks: [Notebook] = try await APIService.shared.get("notebooks")
            for notebook in notebooks.filter({ $0.deletedAt == nil }) {
                try dataStore.saveNotebook(notebook, syncStatus: .synced)
            }

        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Process a note received from the server
    private func processServerNote(_ serverNote: Note) async throws {
        // Check if we have a local version
        if let localNote = try dataStore.fetchNote(id: serverNote.id) {
            // Check for conflicts
            if localNote.syncStatus.isPending && localNote.serverVersion != serverNote.version {
                // Conflict: local has pending changes and server has been updated
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let serverData = try encoder.encode(serverNote)
                try dataStore.markNoteConflict(id: serverNote.id, serverData: serverData)
                hasConflicts = true
            } else if !localNote.syncStatus.isPending {
                // No local changes, just update
                if serverNote.deletedAt != nil {
                    try dataStore.hardDeleteNote(id: serverNote.id)
                } else {
                    try dataStore.saveNote(serverNote, syncStatus: .synced)
                }
            }
            // If local has pending changes but server version matches, keep local
        } else {
            // New note from server
            if serverNote.deletedAt == nil {
                try dataStore.saveNote(serverNote, syncStatus: .synced)

                // Also fetch images for this note
                let images = try await APIService.shared.getNoteImages(noteId: serverNote.id)
                for image in images {
                    try dataStore.saveNoteImage(image)
                }
            }
        }
    }

    /// Sync a specific note by ID
    func syncNote(id: UUID) async {
        guard NetworkMonitor.shared.isConnected else { return }

        do {
            if let note = try dataStore.fetchNote(id: id) {
                await syncNote(note)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Resolve a conflict for a note
    func resolveConflict(noteId: UUID, keepLocal: Bool) async {
        do {
            try dataStore.resolveConflict(id: noteId, keepLocal: keepLocal)

            // If keeping local, sync it
            if keepLocal {
                await syncNote(id: noteId)
            }

            // Update conflict status
            let conflicts = try dataStore.fetchConflictedNotes()
            hasConflicts = !conflicts.isEmpty

            pendingCount = try dataStore.getPendingCount()

        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Get current sync status
    func refreshStatus() {
        do {
            let metadata = try dataStore.getSyncMetadata()
            lastSyncTime = metadata?.lastSyncTime
            pendingCount = metadata?.pendingCount ?? 0
            isSyncing = metadata?.isSyncing ?? false
            lastError = metadata?.lastError

            let conflicts = try dataStore.fetchConflictedNotes()
            hasConflicts = !conflicts.isEmpty
        } catch {
            lastError = error.localizedDescription
        }
    }
}
