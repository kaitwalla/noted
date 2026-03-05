import Foundation
import SwiftData

/// Local SwiftData model for notebooks with sync tracking
@Model
final class LocalNotebook {
    /// Unique identifier matching server notebook ID
    @Attribute(.unique) var id: UUID

    /// Notebook title
    var title: String

    /// When the notebook was created
    var createdAt: Date

    /// When the notebook was last updated
    var updatedAt: Date

    /// When the notebook was soft-deleted (nil if not deleted)
    var deletedAt: Date?

    /// Display order
    var sortOrder: Int

    // MARK: - Sync Tracking

    /// Current synchronization status
    var syncStatusRaw: Int

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    /// Last known server version
    var serverVersion: Int

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        sortOrder: Int = 0,
        syncStatus: SyncStatus = .synced,
        serverVersion: Int = 1
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.sortOrder = sortOrder
        self.syncStatusRaw = syncStatus.rawValue
        self.serverVersion = serverVersion
    }
}
