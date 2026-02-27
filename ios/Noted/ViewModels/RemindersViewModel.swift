import Foundation
import Observation

@Observable
final class RemindersViewModel {
    var reminders: [ReminderItem] = []
    var isLoading = false

    private let localData = LocalDataService.shared
    private let notificationService = NotificationService.shared

    @MainActor
    func fetchReminders() async {
        isLoading = true

        let notebooks = localData.fetchNotebooks()
        var allReminders: [ReminderItem] = []

        for notebook in notebooks {
            let notes = localData.fetchNotes(notebookId: notebook.id)
            let notesWithReminders = notes.filter { $0.reminderAt != nil }

            allReminders.append(contentsOf: notesWithReminders.compactMap { note in
                guard let reminderAt = note.reminderAt else { return nil }
                return ReminderItem(
                    id: note.id,
                    notebookId: notebook.id,
                    content: note.plainText,
                    reminderAt: reminderAt,
                    notebookTitle: notebook.title
                )
            })
        }

        reminders = allReminders.sorted { $0.reminderAt < $1.reminderAt }
        isLoading = false
    }

    @MainActor
    func clearReminder(_ noteId: UUID) async {
        // Update locally - clear the reminder
        _ = localData.updateNote(id: noteId, reminderAt: .some(nil))

        // Cancel notification
        notificationService.cancelReminder(for: noteId)

        // Remove from list
        reminders.removeAll { $0.id == noteId }
    }
}
