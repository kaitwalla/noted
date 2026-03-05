import Foundation
import SwiftUI
import AppKit

struct PendingImage: Identifiable {
    let id = UUID()
    let image: NSImage
    let data: Data
}

@MainActor
final class QuickNoteViewModel: ObservableObject {
    @Published var noteText = ""
    @Published var isSending = false
    @Published var error: String?
    @Published var showSuccess = false
    @Published var pendingImages: [PendingImage] = []
    @Published var keepFullSize = false

    func sendNote(to notebookId: UUID) async -> Bool {
        let hasText = !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !pendingImages.isEmpty

        guard hasText || hasImages else {
            return false
        }

        isSending = true
        error = nil

        do {
            // Create the note (use empty string if only images)
            let content = hasText ? noteText : ""
            let request = NoteCreateRequest(
                content: .text(content),
                plainText: content,
                isTodo: false,
                isDone: false
            )

            let note: Note = try await APIService.shared.post("notebooks/\(notebookId.uuidString)/notes", body: request)

            // Upload images
            for pending in pendingImages {
                let imageData: Data
                if keepFullSize {
                    imageData = pending.data
                } else {
                    imageData = ImageProcessor.resizeImageIfNeeded(pending.image, pending.data)
                }

                _ = try await APIService.shared.uploadImage(
                    imageData,
                    filename: "image.jpg",
                    noteId: note.id,
                    keepFullSize: keepFullSize
                )
            }

            noteText = ""
            pendingImages.removeAll()
            keepFullSize = false
            showSuccess = true
            isSending = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSending = false
            return false
        }
    }

    func addImages(_ images: [NSImage]) {
        for image in images {
            if let data = ImageProcessor.imageToJpegData(image) {
                pendingImages.append(PendingImage(image: image, data: data))
            }
        }
    }

    func removeImage(at index: Int) {
        guard index < pendingImages.count else { return }
        pendingImages.remove(at: index)
    }

    func reset() {
        noteText = ""
        error = nil
        showSuccess = false
        pendingImages.removeAll()
        keepFullSize = false
    }

    /// Clears only transient state (error, success) but preserves note content
    func clearTransientState() {
        error = nil
        showSuccess = false
    }

}
