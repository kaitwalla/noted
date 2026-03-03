import Foundation
import SwiftUI

@MainActor
final class QuickNoteViewModel: ObservableObject {
    @Published var noteText = ""
    @Published var isSending = false
    @Published var error: String?
    @Published var showSuccess = false

    func sendNote(to notebookId: UUID) async -> Bool {
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        isSending = true
        error = nil

        let request = NoteCreateRequest(
            content: .text(noteText),
            plainText: noteText,
            isTodo: false,
            isDone: false
        )

        do {
            let _: Note = try await APIService.shared.post("notebooks/\(notebookId.uuidString)/notes", body: request)
            noteText = ""
            showSuccess = true
            isSending = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSending = false
            return false
        }
    }

    func reset() {
        noteText = ""
        error = nil
        showSuccess = false
    }
}
