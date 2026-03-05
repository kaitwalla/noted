import Foundation

/// Represents the synchronization status of a local entity
enum SyncStatus: Int, Codable {
    /// Fully synchronized with server
    case synced = 0
    /// Created locally, needs to be pushed to server
    case pendingCreate = 1
    /// Modified locally, needs to be pushed to server
    case pendingUpdate = 2
    /// Deleted locally, needs to be deleted on server
    case pendingDelete = 3
    /// Local and server versions conflict, needs user resolution
    case conflict = 4

    var isPending: Bool {
        switch self {
        case .pendingCreate, .pendingUpdate, .pendingDelete:
            return true
        case .synced, .conflict:
            return false
        }
    }

    var iconName: String {
        switch self {
        case .synced:
            return "checkmark.icloud"
        case .pendingCreate, .pendingUpdate:
            return "icloud.and.arrow.up"
        case .pendingDelete:
            return "icloud.slash"
        case .conflict:
            return "exclamationmark.icloud"
        }
    }
}
