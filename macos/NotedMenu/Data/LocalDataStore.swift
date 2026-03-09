import Foundation
import SwiftData
import os.log

/// Main interface for local database operations
@MainActor
final class LocalDataStore {
    static let shared = LocalDataStore()

    private var container: ModelContainer?
    private var context: ModelContext?
    private let logger = Logger(subsystem: "com.noted.NotedMenu", category: "LocalDataStore")

    /// Whether the data store was successfully initialized
    private(set) var isInitialized = false

    private init() {}

    // MARK: - Initialization

    func initialize() throws {
        let schema = Schema([
            LocalNote.self,
            LocalNotebook.self,
            LocalNoteImage.self,
            SyncMetadata.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        context = ModelContext(container!)

        // Ensure sync metadata exists
        try ensureSyncMetadata()

        isInitialized = true
        logger.info("LocalDataStore initialized successfully")
    }

    private func ensureSyncMetadata() throws {
        guard let context = context else { return }

        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.key == "default" }
        )
        let existing = try context.fetch(descriptor)

        if existing.isEmpty {
            let metadata = SyncMetadata()
            context.insert(metadata)
            try context.save()
        }
    }

    // MARK: - Notebooks

    func saveNotebook(_ notebook: Notebook, syncStatus: SyncStatus = .synced) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNotebook>(
            predicate: #Predicate { $0.id == notebook.id }
        )
        let existing = try context.fetch(descriptor)

        if let local = existing.first {
            local.title = notebook.title
            local.updatedAt = notebook.updatedAt
            local.deletedAt = notebook.deletedAt
            local.sortOrder = notebook.sortOrder
            if syncStatus != .synced || local.syncStatus == .synced {
                local.syncStatus = syncStatus
            }
        } else {
            let local = LocalNotebook(
                id: notebook.id,
                title: notebook.title,
                createdAt: notebook.createdAt,
                updatedAt: notebook.updatedAt,
                deletedAt: notebook.deletedAt,
                sortOrder: notebook.sortOrder,
                syncStatus: syncStatus
            )
            context.insert(local)
        }

        try context.save()
    }

    func saveNotebooks(_ notebooks: [Notebook]) throws {
        for notebook in notebooks {
            try saveNotebook(notebook)
        }
    }

    func fetchNotebooks() throws -> [LocalNotebook] {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNotebook>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor)
    }

    func deleteNotebook(id: UUID, syncStatus: SyncStatus = .pendingDelete) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNotebook>(
            predicate: #Predicate { $0.id == id }
        )
        if let notebook = try context.fetch(descriptor).first {
            if syncStatus == .pendingDelete {
                notebook.deletedAt = Date()
                notebook.syncStatus = syncStatus
            } else {
                context.delete(notebook)
            }
            try context.save()
        }
    }

    // MARK: - Notes

    func saveNote(_ note: Note, syncStatus: SyncStatus = .synced) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let contentJSON = String(data: try encoder.encode(note.content), encoding: .utf8) ?? "{}"
        let linkPreviewsJSON: String?
        if let previews = note.linkPreviews {
            linkPreviewsJSON = String(data: try encoder.encode(previews), encoding: .utf8)
        } else {
            linkPreviewsJSON = nil
        }

        let noteId = note.id
        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == noteId }
        )
        let existing = try context.fetch(descriptor)

        if let local = existing.first {
            local.plainText = note.plainText
            local.contentJSON = contentJSON
            local.version = note.version
            local.updatedAt = note.updatedAt
            local.deletedAt = note.deletedAt
            local.isStarred = note.isStarred
            local.linkPreviewsJSON = linkPreviewsJSON
            if syncStatus != .synced || local.syncStatus == .synced {
                local.syncStatus = syncStatus
            }
            if syncStatus == .synced {
                local.serverVersion = note.version
                local.conflictJSON = nil
            }
        } else {
            let local = LocalNote(
                id: note.id,
                notebookId: note.notebookId,
                plainText: note.plainText,
                contentJSON: contentJSON,
                version: note.version,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
                deletedAt: note.deletedAt,
                isStarred: note.isStarred,
                linkPreviewsJSON: linkPreviewsJSON,
                syncStatus: syncStatus,
                serverVersion: note.version
            )
            context.insert(local)
        }

        try context.save()
    }

    func createLocalNote(
        notebookId: UUID,
        plainText: String
    ) throws -> LocalNote {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let encoder = JSONEncoder()
        let content = NoteContent.text(plainText)
        let contentJSON = String(data: try encoder.encode(content), encoding: .utf8) ?? "{}"

        let note = LocalNote(
            id: UUID(),
            notebookId: notebookId,
            plainText: plainText,
            contentJSON: contentJSON,
            version: 1,
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pendingCreate,
            serverVersion: 0
        )

        context.insert(note)
        try context.save()
        try updatePendingCount()

        return note
    }

    func updateLocalNote(
        id: UUID,
        plainText: String,
        content: NoteContent? = nil
    ) throws -> LocalNote? {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == id }
        )
        guard let note = try context.fetch(descriptor).first else { return nil }

        let encoder = JSONEncoder()
        let noteContent = content ?? NoteContent.text(plainText)
        note.plainText = plainText
        note.contentJSON = String(data: try encoder.encode(noteContent), encoding: .utf8) ?? "{}"

        note.updatedAt = Date()
        note.version += 1

        // Only change sync status if it was synced
        if note.syncStatus == .synced {
            note.syncStatus = .pendingUpdate
        }

        try context.save()
        try updatePendingCount()

        return note
    }

    func fetchNotes(notebookId: UUID) throws -> [LocalNote] {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let pendingDeleteStatus = SyncStatus.pendingDelete.rawValue
        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate {
                $0.notebookId == notebookId &&
                $0.deletedAt == nil &&
                $0.syncStatusRaw != pendingDeleteStatus
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchNote(id: UUID) throws -> LocalNote? {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func deleteNote(id: UUID, hardDelete: Bool = false) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == id }
        )
        guard let note = try context.fetch(descriptor).first else { return }

        if hardDelete || note.syncStatus == .pendingCreate {
            // Hard delete: remove from database entirely
            // Also delete associated images
            try deleteImagesForNote(noteId: id, hardDelete: true)
            context.delete(note)
        } else {
            // Soft delete: mark for sync
            note.deletedAt = Date()
            note.syncStatus = .pendingDelete
        }

        try context.save()
        try updatePendingCount()
    }

    // MARK: - Note Images

    func saveNoteImage(_ image: NoteImage, localPath: String? = nil) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let imageId = image.id
        let descriptor = FetchDescriptor<LocalNoteImage>(
            predicate: #Predicate { $0.id == imageId }
        )
        let existing = try context.fetch(descriptor)

        if let local = existing.first {
            local.storageKey = image.storageKey
            local.url = image.url
            if localPath != nil {
                local.localPath = localPath
            }
            local.syncStatus = .synced
        } else {
            let local = LocalNoteImage(
                id: image.id,
                noteId: image.noteId,
                filename: image.filename,
                mimeType: image.mimeType,
                storageKey: image.storageKey,
                size: image.size,
                createdAt: image.createdAt,
                url: image.url,
                localPath: localPath,
                syncStatus: .synced
            )
            context.insert(local)
        }

        try context.save()
    }

    func createLocalImage(
        noteId: UUID,
        filename: String,
        size: Int64,
        localPath: String,
        keepFullSize: Bool = false
    ) throws -> LocalNoteImage {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let image = LocalNoteImage(
            id: UUID(),
            noteId: noteId,
            filename: filename,
            size: size,
            localPath: localPath,
            syncStatus: .pendingCreate,
            keepFullSize: keepFullSize
        )

        context.insert(image)
        try context.save()
        try updatePendingCount()

        return image
    }

    func fetchImages(noteId: UUID) throws -> [LocalNoteImage] {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNoteImage>(
            predicate: #Predicate { $0.noteId == noteId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func reassignImages(fromNoteId: UUID, toNoteId: UUID) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNoteImage>(
            predicate: #Predicate { $0.noteId == fromNoteId }
        )
        let images = try context.fetch(descriptor)

        for image in images {
            image.noteId = toNoteId
        }

        try context.save()
    }

    func deleteImagesForNote(noteId: UUID, hardDelete: Bool = false) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNoteImage>(
            predicate: #Predicate { $0.noteId == noteId }
        )
        let images = try context.fetch(descriptor)

        for image in images {
            if hardDelete {
                context.delete(image)
            } else {
                image.syncStatus = .pendingDelete
            }
        }

        try context.save()
    }

    // MARK: - Sync Operations

    func fetchPendingNotes() throws -> [LocalNote] {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate ||
                $0.syncStatusRaw == pendingUpdate ||
                $0.syncStatusRaw == pendingDelete
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        return try context.fetch(descriptor)
    }

    func fetchPendingImages() throws -> [LocalNoteImage] {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let pendingCreate = SyncStatus.pendingCreate.rawValue

        let descriptor = FetchDescriptor<LocalNoteImage>(
            predicate: #Predicate { $0.syncStatusRaw == pendingCreate },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func fetchConflictedNotes() throws -> [LocalNote] {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let conflictStatus = SyncStatus.conflict.rawValue
        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.syncStatusRaw == conflictStatus }
        )
        return try context.fetch(descriptor)
    }

    func markNoteSynced(id: UUID, serverVersion: Int) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == id }
        )
        if let note = try context.fetch(descriptor).first {
            note.syncStatus = .synced
            note.serverVersion = serverVersion
            note.conflictJSON = nil
            try context.save()
            try updatePendingCount()
        }
    }

    func markNoteConflict(id: UUID, serverData: Data) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == id }
        )
        if let note = try context.fetch(descriptor).first {
            note.syncStatus = .conflict
            note.conflictJSON = String(data: serverData, encoding: .utf8)
            try context.save()
        }
    }

    func resolveConflict(id: UUID, keepLocal: Bool) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == id }
        )
        guard let note = try context.fetch(descriptor).first else { return }

        if keepLocal {
            // Keep local version, mark for update
            note.syncStatus = .pendingUpdate
            note.conflictJSON = nil
        } else {
            // Apply server version
            if let conflictJSON = note.conflictJSON,
               let data = conflictJSON.data(using: .utf8) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let serverNote = try? decoder.decode(Note.self, from: data) {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    note.plainText = serverNote.plainText
                    note.contentJSON = String(data: (try? encoder.encode(serverNote.content)) ?? Data(), encoding: .utf8) ?? "{}"
                    note.version = serverNote.version
                    note.updatedAt = serverNote.updatedAt
                    note.serverVersion = serverNote.version
                }
            }
            note.syncStatus = .synced
            note.conflictJSON = nil
        }

        try context.save()
        try updatePendingCount()
    }

    func hardDeleteNote(id: UUID) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate { $0.id == id }
        )
        if let note = try context.fetch(descriptor).first {
            // Delete associated images first
            try deleteImagesForNote(noteId: id, hardDelete: true)
            context.delete(note)
            try context.save()
            try updatePendingCount()
        }
    }

    // MARK: - Sync Metadata

    func getSyncMetadata() throws -> SyncMetadata? {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.key == "default" }
        )
        return try context.fetch(descriptor).first
    }

    func updateLastSyncTime(_ date: Date) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        if let metadata = try getSyncMetadata() {
            metadata.lastSyncTime = date
            metadata.lastError = nil
            try context.save()
        }
    }

    func setSyncError(_ error: String?) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        if let metadata = try getSyncMetadata() {
            metadata.lastError = error
            try context.save()
        }
    }

    func setSyncing(_ isSyncing: Bool) throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        if let metadata = try getSyncMetadata() {
            metadata.isSyncing = isSyncing
            try context.save()
        }
    }

    private func updatePendingCount() throws {
        guard let context = context else { return }

        let pendingNotes = try fetchPendingNotes()
        let pendingImages = try fetchPendingImages()
        let count = pendingNotes.count + pendingImages.count

        if let metadata = try getSyncMetadata() {
            metadata.pendingCount = count
            try context.save()
        }
    }

    func getPendingCount() throws -> Int {
        return try getSyncMetadata()?.pendingCount ?? 0
    }

    // MARK: - Clear Data

    func clearAllData() throws {
        guard let context = context else { throw LocalDataStoreError.notInitialized }

        // Delete all notes
        let notesDescriptor = FetchDescriptor<LocalNote>()
        let notes = try context.fetch(notesDescriptor)
        for note in notes {
            context.delete(note)
        }

        // Delete all notebooks
        let notebooksDescriptor = FetchDescriptor<LocalNotebook>()
        let notebooks = try context.fetch(notebooksDescriptor)
        for notebook in notebooks {
            context.delete(notebook)
        }

        // Delete all images
        let imagesDescriptor = FetchDescriptor<LocalNoteImage>()
        let images = try context.fetch(imagesDescriptor)
        for image in images {
            context.delete(image)
        }

        // Reset sync metadata
        if let metadata = try getSyncMetadata() {
            metadata.lastSyncTime = nil
            metadata.pendingCount = 0
            metadata.lastError = nil
            metadata.isSyncing = false
        }

        try context.save()
    }
}

// MARK: - Errors

enum LocalDataStoreError: LocalizedError {
    case notInitialized
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Local database not initialized"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}
