import Foundation
import Observation
import UIKit

@Observable
final class ImagesViewModel {
    var images: [NoteImage] = []
    var isLoading = false
    var isUploading = false
    var uploadProgress: Double = 0.0
    var errorMessage: String?

    private let imageService = ImageService.shared

    @MainActor
    func fetchImages(noteId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            images = try await imageService.fetchImages(noteId: noteId)
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func uploadImage(_ image: UIImage, noteId: UUID) async -> NoteImage? {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil

        do {
            let noteImage = try await imageService.uploadImage(image, noteId: noteId)
            images.append(noteImage)
            isUploading = false
            return noteImage
        } catch {
            self.errorMessage = error.localizedDescription
            isUploading = false
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
