import Foundation
import SwiftData

/// Local SwiftData model for notes with sync tracking
@Model
final class LocalNote {
    /// Unique identifier matching server note ID
    @Attribute(.unique) var id: UUID

    /// Parent notebook ID
    var notebookId: UUID

    /// Plain text content of the note
    var plainText: String

    /// JSON-encoded content structure (type and formatted content)
    var contentJSON: String

    /// Whether this note is a todo item
    var isTodo: Bool

    /// Whether this todo is completed
    var isDone: Bool

    /// Note version for conflict detection
    var version: Int

    /// When the note was created
    var createdAt: Date

    /// When the note was last updated
    var updatedAt: Date

    /// When the note was soft-deleted (nil if not deleted)
    var deletedAt: Date?

    /// Link previews as JSON
    var linkPreviewsJSON: String?

    // MARK: - Sync Tracking

    /// Current synchronization status
    var syncStatusRaw: Int

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    /// Last known server version for conflict detection
    var serverVersion: Int

    /// JSON-encoded server data when in conflict state
    var conflictJSON: String?

    init(
        id: UUID = UUID(),
        notebookId: UUID,
        plainText: String,
        contentJSON: String,
        isTodo: Bool = false,
        isDone: Bool = false,
        version: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        linkPreviewsJSON: String? = nil,
        syncStatus: SyncStatus = .synced,
        serverVersion: Int = 1,
        conflictJSON: String? = nil
    ) {
        self.id = id
        self.notebookId = notebookId
        self.plainText = plainText
        self.contentJSON = contentJSON
        self.isTodo = isTodo
        self.isDone = isDone
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.linkPreviewsJSON = linkPreviewsJSON
        self.syncStatusRaw = syncStatus.rawValue
        self.serverVersion = serverVersion
        self.conflictJSON = conflictJSON
    }
}
