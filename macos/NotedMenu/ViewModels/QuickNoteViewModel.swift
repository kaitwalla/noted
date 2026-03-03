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

    private let maxDimension: CGFloat = 2000

    func sendNote(to notebookId: UUID) async -> Bool {
        let hasText = !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !pendingImages.isEmpty

        guard hasText || hasImages else {
            return false
        }

        isSending = true
        error = nil

        do {
            // Create the note
            let content = hasText ? noteText : "[image]"
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
                    imageData = resizeImageIfNeeded(pending.image, pending.data)
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
            if let data = imageToJpegData(image) {
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

    // MARK: - Image Processing

    private func imageToJpegData(_ image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    private func resizeImageIfNeeded(_ image: NSImage, _ originalData: Data) -> Data {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return originalData
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()

        if let data = imageToJpegData(resized) {
            return data
        }
        return originalData
    }
}
