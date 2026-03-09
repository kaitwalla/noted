import Foundation

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    let notebookId: UUID
    var content: NoteContent
    var plainText: String
    var isStarred: Bool
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
        case isStarred = "is_starred"
        case reminderAt = "reminder_at"
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case linkPreviews = "link_previews"
    }
}

/// Tiptap-compatible JSON content, matching the web editor format.
struct NoteContent: Equatable {
    var rawJSON: [String: Any]

    /// Create a Tiptap doc wrapping a simple text string
    static func text(_ content: String) -> NoteContent {
        let json: [String: Any] = [
            "type": "doc",
            "content": [
                [
                    "type": "paragraph",
                    "content": [
                        ["type": "text", "text": content]
                    ]
                ] as [String: Any]
            ]
        ]
        return NoteContent(rawJSON: json)
    }

    static func == (lhs: NoteContent, rhs: NoteContent) -> Bool {
        guard let lData = try? JSONSerialization.data(withJSONObject: lhs.rawJSON, options: .sortedKeys),
              let rData = try? JSONSerialization.data(withJSONObject: rhs.rawJSON, options: .sortedKeys) else {
            return false
        }
        return lData == rData
    }
}

extension NoteContent: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodableValue].self) {
            rawJSON = dict.mapValues { $0.value }
        } else {
            rawJSON = ["type": "doc", "content": [] as [Any]]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let wrapped = rawJSON.mapValues { AnyCodableValue($0) }
        try container.encode(wrapped)
    }
}

/// Helper for encoding/decoding arbitrary JSON values
enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dict([String: AnyCodableValue])
    case null

    var value: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .array(let v): return v.map { $0.value }
        case .dict(let v): return v.mapValues { $0.value }
        case .null: return NSNull()
        }
    }

    init(_ value: Any) {
        switch value {
        case let b as Bool: self = .bool(b)
        case let i as Int: self = .int(i)
        case let d as Double: self = .double(d)
        case let s as String: self = .string(s)
        case let a as [Any]: self = .array(a.map { AnyCodableValue($0) })
        case let d as [String: Any]: self = .dict(d.mapValues { AnyCodableValue($0) })
        default: self = .null
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else if let s = try? container.decode(String.self) { self = .string(s) }
        else if let a = try? container.decode([AnyCodableValue].self) { self = .array(a) }
        else if let d = try? container.decode([String: AnyCodableValue].self) { self = .dict(d) }
        else if container.decodeNil() { self = .null }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .dict(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodableValue, rhs: AnyCodableValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.double(let a), .double(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.dict(let a), .dict(let b)): return a == b
        case (.null, .null): return true
        default: return false
        }
    }
}

struct NoteCreateRequest: Codable {
    let content: NoteContent
    let plainText: String

    enum CodingKeys: String, CodingKey {
        case content
        case plainText = "plain_text"
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
        self.isStarred = localNote.isStarred
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
