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
    var linkPreviews: [LinkPreview]?

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
        case linkPreviews = "link_previews"
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
    let content: NoteContent
    let plainText: String
    let isTodo: Bool
    let isDone: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case plainText = "plain_text"
        case isTodo = "is_todo"
        case isDone = "is_done"
    }
}

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

struct LinkPreview: Codable, Identifiable, Equatable {
    let id: UUID
    let url: String
    var title: String?
    var description: String?
    var imageUrl: String?
    var faviconUrl: String?
    var siteName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case title
        case description
        case imageUrl = "image_url"
        case faviconUrl = "favicon_url"
        case siteName = "site_name"
    }
}

// MARK: - LocalNote Conversion

extension Note {
    /// Create a Note from a LocalNote
    init(from localNote: LocalNote) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let content: NoteContent
        if let data = localNote.contentJSON.data(using: .utf8),
           let decoded = try? decoder.decode(NoteContent.self, from: data) {
            content = decoded
        } else {
            content = .text(localNote.plainText)
        }

        let linkPreviews: [LinkPreview]?
        if let json = localNote.linkPreviewsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? decoder.decode([LinkPreview].self, from: data) {
            linkPreviews = decoded
        } else {
            linkPreviews = nil
        }

        self.id = localNote.id
        self.notebookId = localNote.notebookId
        self.content = content
        self.plainText = localNote.plainText
        self.isTodo = localNote.isTodo
        self.isDone = localNote.isDone
        self.reminderAt = nil
        self.version = localNote.version
        self.createdAt = localNote.createdAt
        self.updatedAt = localNote.updatedAt
        self.deletedAt = localNote.deletedAt
        self.linkPreviews = linkPreviews
    }
}

extension NoteImage {
    /// Create a NoteImage from a LocalNoteImage
    init(from localImage: LocalNoteImage) {
        self.id = localImage.id
        self.noteId = localImage.noteId
        self.filename = localImage.filename
        self.mimeType = localImage.mimeType
        self.storageKey = localImage.storageKey
        self.size = localImage.size
        self.createdAt = localImage.createdAt
        self.url = localImage.url
    }
}
