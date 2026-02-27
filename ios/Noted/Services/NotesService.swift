import Foundation

final class NotesService {
    static let shared = NotesService()

    private let api = APIService.shared

    private init() {}

    func fetchAll(notebookId: UUID) async throws -> [Note] {
        try await api.get("notebooks/\(notebookId.uuidString)/notes")
    }

    func create(notebookId: UUID, content: String, isTodo: Bool = false) async throws -> Note {
        let request = NoteCreateRequest(
            notebookId: notebookId,
            content: .text(content),
            plainText: content,
            isTodo: isTodo,
            isDone: false,
            reminderAt: nil
        )
        return try await api.post("notes", body: request)
    }

    func update(
        id: UUID,
        content: String? = nil,
        isTodo: Bool? = nil,
        isDone: Bool? = nil,
        reminderAt: Date? = nil
    ) async throws -> Note {
        let request = NoteUpdateRequest(
            content: content.map { .text($0) },
            plainText: content,
            isTodo: isTodo,
            isDone: isDone,
            reminderAt: reminderAt
        )
        return try await api.patch("notes/\(id.uuidString)", body: request)
    }

    func delete(id: UUID) async throws {
        try await api.delete("notes/\(id.uuidString)")
    }
}
