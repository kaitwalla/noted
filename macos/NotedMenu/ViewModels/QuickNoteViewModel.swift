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

    private let dataStore = LocalDataStore.shared
    private let imageCache = ImageCacheService.shared
    private let syncService = SyncService.shared

    func sendNote(to notebookId: UUID) async -> Bool {
        let hasText = !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !pendingImages.isEmpty

        guard hasText || hasImages else {
            return false
        }

        isSending = true
        error = nil

        // Always save locally first for immediate UI feedback
        let content = hasText ? noteText : ""

        do {
            // Create local note
            let localNote = try dataStore.createLocalNote(
                notebookId: notebookId,
                plainText: content,
                isTodo: false,
                isDone: false
            )

            // Save images locally
            for pending in pendingImages {
                let imageData: Data
                if keepFullSize {
                    imageData = pending.data
                } else {
                    imageData = ImageProcessor.resizeImageIfNeeded(pending.image, pending.data)
                }

                // Save to local cache
                let localPath = try imageCache.saveImage(imageData, noteId: localNote.id, filename: "image.jpg")

                // Create local image record
                _ = try dataStore.createLocalImage(
                    noteId: localNote.id,
                    filename: "image.jpg",
                    size: Int64(imageData.count),
                    localPath: localPath,
                    keepFullSize: keepFullSize
                )
            }

            // Clear UI state immediately - user sees success
            noteText = ""
            pendingImages.removeAll()
            keepFullSize = false
            showSuccess = true
            isSending = false

            // Try to sync in the background if online
            if NetworkMonitor.shared.isConnected {
                Task {
                    await syncService.syncNote(id: localNote.id)
                }
            }

            return true

        } catch {
            // Local save failed - this is unexpected
            self.error = "Failed to save note: \(error.localizedDescription)"
            isSending = false
            return false
        }
    }

    /// Legacy method for online-only note creation (fallback)
    func sendNoteOnline(to notebookId: UUID) async -> Bool {
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

            // Save to local storage
            try dataStore.saveNote(note, syncStatus: .synced)

            // Upload images
            for pending in pendingImages {
                let imageData: Data
                if keepFullSize {
                    imageData = pending.data
                } else {
                    imageData = ImageProcessor.resizeImageIfNeeded(pending.image, pending.data)
                }

                let serverImage = try await APIService.shared.uploadImage(
                    imageData,
                    filename: "image.jpg",
                    noteId: note.id,
                    keepFullSize: keepFullSize
                )

                // Save image to local storage
                let localPath = try? imageCache.saveImage(imageData, noteId: note.id, filename: serverImage.filename)
                try dataStore.saveNoteImage(serverImage, localPath: localPath)
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
