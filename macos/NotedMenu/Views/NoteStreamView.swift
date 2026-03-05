import SwiftUI
import AppKit

/// View displaying a stream of notes for a notebook
struct NoteStreamView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors
    let notebook: Notebook

    @State private var notes: [Note] = []
    @State private var noteImages: [UUID: [NoteImage]] = [:]
    @State private var isLoading = true
    @State private var error: String?
    @State private var editingNote: Note?
    @State private var editText: String = ""
    @State private var errorDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(themeColors.border)

            // Notes list
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if let error = error {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(themeColors.secondaryText)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadNotes() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                Spacer()
            } else if notes.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.title)
                        .foregroundColor(themeColors.secondaryText)
                    Text("No notes yet")
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryText)
                }
                Spacer()
            } else {
                notesList
            }

            Divider()
                .background(themeColors.border)

            // Input area
            NoteInputView(notebookId: notebook.id) {
                Task { await loadNotes() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(themeColors.background)
        .task {
            await loadNotes()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                appViewModel.backToNotebooks()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.caption)
                }
                .foregroundColor(themeColors.accent)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back to notebooks")

            Image(systemName: "book.closed")
                .foregroundColor(themeColors.accent)
                .font(.caption)

            Text(notebook.title)
                .font(.headline)
                .foregroundColor(themeColors.text)
                .lineLimit(1)

            Spacer()

            Button {
                Task { await loadNotes() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(themeColors.background)
    }

    private var notesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Notes are sorted newest first, so reverse for chronological display
                    ForEach(notes.reversed()) { note in
                        NoteBubbleView(
                            note: note,
                            images: noteImages[note.id] ?? []
                        )
                        .id(note.id)
                        .contextMenu {
                            Button {
                                startEditing(note)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            if note.isTodo {
                                Button {
                                    Task { await toggleTodo(note) }
                                } label: {
                                    Label(note.isDone ? "Mark Incomplete" : "Mark Complete",
                                          systemImage: note.isDone ? "circle" : "checkmark.circle")
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                Task { await deleteNote(note) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture(count: 2) {
                            startEditing(note)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: notes.count) { _, _ in
                // Scroll to newest note when notes change
                if let lastNote = notes.first {
                    withAnimation {
                        proxy.scrollTo(lastNote.id, anchor: .bottom)
                    }
                }
            }
        }
        .sheet(item: $editingNote) { note in
            NoteEditView(
                note: note,
                text: $editText,
                onSave: { newText in
                    await saveEdit(note: note, newText: newText)
                },
                onCancel: {
                    editingNote = nil
                }
            )
            .themed()
        }
    }

    private func startEditing(_ note: Note) {
        editText = note.plainText
        editingNote = note
    }

    private func saveEdit(note: Note, newText: String) async {
        do {
            let updated = try await APIService.shared.updateNote(
                noteId: note.id,
                plainText: newText,
                isTodo: note.isTodo,
                isDone: note.isDone
            )
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = updated
            }
            editingNote = nil
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func toggleTodo(_ note: Note) async {
        do {
            let updated = try await APIService.shared.updateNote(
                noteId: note.id,
                plainText: note.plainText,
                isTodo: note.isTodo,
                isDone: !note.isDone
            )
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = updated
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func deleteNote(_ note: Note) async {
        do {
            try await APIService.shared.deleteNote(noteId: note.id)
            notes.removeAll { $0.id == note.id }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func loadNotes() async {
        isLoading = notes.isEmpty
        error = nil

        do {
            notes = try await APIService.shared.getNotes(notebookId: notebook.id)

            // Load images in parallel using TaskGroup
            await withTaskGroup(of: (UUID, [NoteImage]).self) { group in
                for note in notes {
                    group.addTask {
                        do {
                            let images = try await APIService.shared.getNoteImages(noteId: note.id)
                            return (note.id, images)
                        } catch {
                            // Return empty array on failure - don't abort other loads
                            return (note.id, [])
                        }
                    }
                }

                for await (noteId, images) in group {
                    noteImages[noteId] = images
                }
            }

            isLoading = false
        } catch {
            showError(error.localizedDescription)
            isLoading = false
        }
    }

    /// Shows an error message that auto-dismisses after 5 seconds
    private func showError(_ message: String) {
        errorDismissTask?.cancel()
        error = message

        errorDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                error = nil
            }
        }
    }
}

// MARK: - Date Grouping (for future enhancement)

extension NoteStreamView {
    struct DateGroup: Identifiable {
        let id: Date
        let notes: [Note]

        var title: String {
            let calendar = Calendar.current
            let now = Date()

            if calendar.isDateInToday(id) {
                return "Today"
            } else if calendar.isDateInYesterday(id) {
                return "Yesterday"
            } else if calendar.isDate(id, equalTo: now, toGranularity: .weekOfYear) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: id)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d"
                return formatter.string(from: id)
            }
        }
    }

    func groupNotesByDate(_ notes: [Note]) -> [DateGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: notes) { note in
            calendar.startOfDay(for: note.createdAt)
        }
        return grouped.map { DateGroup(id: $0.key, notes: $0.value) }
            .sorted { $0.id > $1.id }
    }
}

// MARK: - Note Edit View

struct NoteEditView: View {
    let note: Note
    @Binding var text: String
    var onSave: (String) async -> Void
    var onCancel: () -> Void

    @Environment(\.themeColors) var themeColors
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Edit Note")
                    .font(.headline)
                    .foregroundColor(themeColors.text)

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeColors.secondaryText)
                }
                .buttonStyle(.plain)
            }

            // Text editor
            MarkdownTextView(
                text: $text,
                font: .systemFont(ofSize: NSFont.systemFontSize),
                textColor: themeColors.nsText
            )
            .frame(minHeight: 120, maxHeight: 200)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeColors.tertiaryBackground)
            )

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)

                Button("Save") {
                    Task {
                        isSaving = true
                        await onSave(text)
                        isSaving = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .padding(16)
        .frame(width: 350)
        .background(themeColors.background)
    }
}
