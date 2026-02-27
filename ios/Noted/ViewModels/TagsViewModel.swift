import Foundation
import Observation

@Observable
final class TagsViewModel {
    var tags: [Tag] = []
    var isLoading = false
    var errorMessage: String?

    private let service = TagsService.shared

    @MainActor
    func fetchTags() async {
        isLoading = true
        errorMessage = nil

        do {
            tags = try await service.fetchAll()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func createTag(name: String, color: String?) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Tag name cannot be empty"
            return
        }

        do {
            let tag = try await service.create(name: name, color: color)
            tags.append(tag)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteTag(_ id: UUID) async {
        do {
            try await service.delete(id: id)
            tags.removeAll { $0.id == id }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
