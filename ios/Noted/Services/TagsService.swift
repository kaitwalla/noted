import Foundation

final class TagsService {
    static let shared = TagsService()

    private let api = APIService.shared

    private init() {}

    func fetchAll() async throws -> [Tag] {
        try await api.get("tags")
    }

    func create(name: String, color: String?) async throws -> Tag {
        let request = TagCreateRequest(name: name, color: color)
        return try await api.post("tags", body: request)
    }

    func delete(id: UUID) async throws {
        try await api.delete("tags/\(id.uuidString)")
    }

    func addTagToNote(noteId: UUID, tagId: UUID) async throws {
        let _: Empty = try await api.post("notes/\(noteId.uuidString)/tags/\(tagId.uuidString)", body: Empty())
    }

    func removeTagFromNote(noteId: UUID, tagId: UUID) async throws {
        try await api.delete("notes/\(noteId.uuidString)/tags/\(tagId.uuidString)")
    }
}
