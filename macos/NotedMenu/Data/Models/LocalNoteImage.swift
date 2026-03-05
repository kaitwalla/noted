import Foundation
import SwiftData

/// Local SwiftData model for note images with sync tracking
@Model
final class LocalNoteImage {
    /// Unique identifier matching server image ID
    @Attribute(.unique) var id: UUID

    /// Parent note ID
    var noteId: UUID

    /// Original filename
    var filename: String

    /// MIME type (e.g., "image/jpeg")
    var mimeType: String

    /// Server storage key (empty if not yet uploaded)
    var storageKey: String

    /// File size in bytes
    var size: Int64

    /// When the image was created
    var createdAt: Date

    /// Server URL for the image (nil if not yet uploaded)
    var url: String?

    // MARK: - Local Storage

    /// Local file path relative to app's image cache directory
    var localPath: String?

    // MARK: - Sync Tracking

    /// Current synchronization status
    var syncStatusRaw: Int

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    /// Whether to keep full size when uploading
    var keepFullSize: Bool

    init(
        id: UUID = UUID(),
        noteId: UUID,
        filename: String,
        mimeType: String = "image/jpeg",
        storageKey: String = "",
        size: Int64,
        createdAt: Date = Date(),
        url: String? = nil,
        localPath: String? = nil,
        syncStatus: SyncStatus = .synced,
        keepFullSize: Bool = false
    ) {
        self.id = id
        self.noteId = noteId
        self.filename = filename
        self.mimeType = mimeType
        self.storageKey = storageKey
        self.size = size
        self.createdAt = createdAt
        self.url = url
        self.localPath = localPath
        self.syncStatusRaw = syncStatus.rawValue
        self.keepFullSize = keepFullSize
    }
}
