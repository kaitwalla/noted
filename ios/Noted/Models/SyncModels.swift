import Foundation

// MARK: - Sync Request/Response

struct SyncRequest: Codable {
    let notebooks: [Notebook]
    let notes: [Note]
    let deletedNotebookIds: [UUID]
    let deletedNoteIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case notebooks, notes
        case deletedNotebookIds = "deleted_notebook_ids"
        case deletedNoteIds = "deleted_note_ids"
    }
}

struct SyncResponse: Codable {
    let notebooks: [Notebook]
    let notes: [Note]
    let tags: [Tag]?
    let serverTime: Date?
    let hasConflict: Bool?

    // Support both server formats
    let deletedNotebookIds: [UUID]?
    let deletedNoteIds: [UUID]?

    enum CodingKeys: String, CodingKey {
        case notebooks, notes, tags
        case serverTime = "server_time"
        case hasConflict = "has_conflict"
        case deletedNotebookIds = "deleted_notebook_ids"
        case deletedNoteIds = "deleted_note_ids"
    }
}

// MARK: - Pending Changes

struct PendingChanges {
    var createdNotebooks: [Notebook] = []
    var updatedNotebooks: [Notebook] = []
    var deletedNotebookIds: [UUID] = []

    var createdNotes: [Note] = []
    var updatedNotes: [Note] = []
    var deletedNoteIds: [UUID] = []

    var isEmpty: Bool {
        createdNotebooks.isEmpty &&
        updatedNotebooks.isEmpty &&
        deletedNotebookIds.isEmpty &&
        createdNotes.isEmpty &&
        updatedNotes.isEmpty &&
        deletedNoteIds.isEmpty
    }

    var totalCount: Int {
        createdNotebooks.count +
        updatedNotebooks.count +
        deletedNotebookIds.count +
        createdNotes.count +
        updatedNotes.count +
        deletedNoteIds.count
    }
}

// MARK: - Conflict

struct SyncConflict {
    let entityType: String
    let entityId: UUID
    let localVersion: Int
    let remoteVersion: Int
    let localModifiedAt: Date
    let remoteModifiedAt: Date
}
