import Foundation
import SwiftData

/// Stores sync state metadata
@Model
final class SyncMetadata {
    /// Singleton key for fetching
    @Attribute(.unique) var key: String

    /// Last successful sync timestamp
    var lastSyncTime: Date?

    /// Whether a sync is currently in progress
    var isSyncing: Bool

    /// Last sync error message (nil if successful)
    var lastError: String?

    /// Number of pending operations
    var pendingCount: Int

    init(
        key: String = "default",
        lastSyncTime: Date? = nil,
        isSyncing: Bool = false,
        lastError: String? = nil,
        pendingCount: Int = 0
    ) {
        self.key = key
        self.lastSyncTime = lastSyncTime
        self.isSyncing = isSyncing
        self.lastError = lastError
        self.pendingCount = pendingCount
    }
}
