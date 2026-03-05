import SwiftUI
import UIKit

struct NoteBubble: View {
    let note: Note
    var images: [NoteImage] = []
    let onEdit: (String) -> Void
    let onDelete: () -> Void
    let onToggleTodo: () -> Void

    @Environment(\.themeColors) private var colors
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 4) {
                // Images
                if !images.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(images) { image in
                            AsyncNoteImage(imageId: image.id, url: image.url)
                                .frame(maxWidth: 250)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(colors.accent.opacity(0.15))
                    .cornerRadius(18)
                }

                // Link previews
                if let previews = note.linkPreviews, !previews.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(previews) { preview in
                            LinkPreviewCard(preview: preview)
                        }
                    }
                }

                // Text content (if any)
                if !note.plainText.isEmpty {
                    // Bubble content
                    HStack(spacing: 8) {
                        if note.isTodo {
                            Button {
                                HapticService.shared.selection()
                                onToggleTodo()
                            } label: {
                                Image(systemName: note.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(note.isDone ? colors.success : colors.secondaryText)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                        }

                        Text(note.content.content)
                            .strikethrough(note.isTodo && note.isDone)
                            .foregroundStyle(note.isTodo && note.isDone ? colors.secondaryText : colors.text)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colors.accent.opacity(0.15))
                    .cornerRadius(18)
                    .contextMenu {
                        Button {
                            editText = note.content.content
                            isEditing = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            HapticService.shared.lightTap()
                            UIPasteboard.general.string = note.content.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(role: .destructive) {
                            HapticService.shared.warning()
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // Reminder indicator
                if let reminderAt = note.reminderAt {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                        Text(formatReminderDate(reminderAt))
                            .font(.caption2)
                    }
                    .foregroundStyle(reminderAt < Date() ? colors.error : colors.secondaryText)
                }

                // Timestamp
                Text(formatTime(note.createdAt))
                    .font(.caption2)
                    .foregroundStyle(colors.secondaryText)
            }
        }
        .sheet(isPresented: $isEditing) {
            EditNoteSheet(
                text: $editText,
                onSave: {
                    onEdit(editText)
                    isEditing = false
                }
            )
        }
    }

    private func formatReminderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EditNoteSheet: View {
    @Binding var text: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .padding()
                .navigationTitle("Edit Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear {
                    isFocused = true
                }
        }
    }
}

#Preview {
    VStack {
        NoteBubble(
            note: Note(
                id: UUID(),
                notebookId: UUID(),
                content: .text("This is a test note with some content"),
                plainText: "This is a test note with some content",
                isTodo: false,
                isDone: false,
                reminderAt: nil,
                version: 1,
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil
            ),
            onEdit: { _ in },
            onDelete: {},
            onToggleTodo: {}
        )

        NoteBubble(
            note: Note(
                id: UUID(),
                notebookId: UUID(),
                content: .text("This is a todo item"),
                plainText: "This is a todo item",
                isTodo: true,
                isDone: false,
                reminderAt: nil,
                version: 1,
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil
            ),
            onEdit: { _ in },
            onDelete: {},
            onToggleTodo: {}
        )
    }
    .padding()
}
