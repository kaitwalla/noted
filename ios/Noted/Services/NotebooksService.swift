import Foundation

final class NotebooksService {
    static let shared = NotebooksService()

    private let api = APIService.shared

    private init() {}

    func fetchAll() async throws -> [Notebook] {
        try await api.get("notebooks")
    }

    func create(title: String) async throws -> Notebook {
        let request = NotebookCreateRequest(title: title)
        return try await api.post("notebooks", body: request)
    }

    func update(id: UUID, title: String? = nil, sortOrder: Int? = nil) async throws -> Notebook {
        let request = NotebookUpdateRequest(title: title, sortOrder: sortOrder)
        return try await api.patch("notebooks/\(id.uuidString)", body: request)
    }

    func delete(id: UUID) async throws {
        try await api.delete("notebooks/\(id.uuidString)")
    }
}
