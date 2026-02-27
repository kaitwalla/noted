import Foundation

struct NoteImage: Codable, Identifiable, Equatable {
    let id: UUID
    let noteId: UUID
    let filename: String
    let mimeType: String
    let storageKey: String
    let size: Int64
    let createdAt: Date
    var url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case filename
        case mimeType = "mime_type"
        case storageKey = "storage_key"
        case size
        case createdAt = "created_at"
        case url
    }
}
