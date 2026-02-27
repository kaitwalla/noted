import Foundation

struct Notebook: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case sortOrder = "sort_order"
    }
}

struct NotebookCreateRequest: Codable {
    let title: String
}

struct NotebookUpdateRequest: Codable {
    let title: String?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case sortOrder = "sort_order"
    }
}
