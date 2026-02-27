import Foundation

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    let notebookId: UUID
    var content: NoteContent
    var plainText: String
    var isTodo: Bool
    var isDone: Bool
    var reminderAt: Date?
    var version: Int
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case notebookId = "notebook_id"
        case content
        case plainText = "plain_text"
        case isTodo = "is_todo"
        case isDone = "is_done"
        case reminderAt = "reminder_at"
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct NoteContent: Codable, Equatable {
    var type: String
    var content: String

    static func text(_ content: String) -> NoteContent {
        NoteContent(type: "text", content: content)
    }
}

struct NoteCreateRequest: Codable {
    let notebookId: UUID
    let content: NoteContent
    let plainText: String
    let isTodo: Bool
    let isDone: Bool
    let reminderAt: Date?

    enum CodingKeys: String, CodingKey {
        case notebookId = "notebook_id"
        case content
        case plainText = "plain_text"
        case isTodo = "is_todo"
        case isDone = "is_done"
        case reminderAt = "reminder_at"
    }
}

struct NoteUpdateRequest: Codable {
    let content: NoteContent?
    let plainText: String?
    let isTodo: Bool?
    let isDone: Bool?
    let reminderAt: Date?

    enum CodingKeys: String, CodingKey {
        case content
        case plainText = "plain_text"
        case isTodo = "is_todo"
        case isDone = "is_done"
        case reminderAt = "reminder_at"
    }
}
