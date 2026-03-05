import SwiftUI
import AppKit

/// View displaying a stream of notes for a notebook
struct NoteStreamView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.themeColors) var themeColors
    let notebook: Notebook

    @State private var notes: [Note] = []
    @State private var noteImages: [UUID: [NoteImage]] = [:]
    @State private var noteSyncStatus: [UUID: SyncStatus] = [:]
    @State private var isLoading = true
    @State private var error: String?
    @State private var editingNote: Note?
    @State private var editText: String = ""
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var conflictNote: LocalNote?
    @State private var showingConflict = false

    private let dataStore = LocalDataStore.shared
    private let syncService = SyncService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Offline banner
            if !appViewModel.isOnline {
                offlineBanner
            }

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
        .sheet(isPresented: $showingConflict) {
            if let note = conflictNote {
                ConflictResolutionView(
                    localNote: note,
                    onResolve: { keepLocal in
                        Task {
                            await syncService.resolveConflict(noteId: note.id, keepLocal: keepLocal)
                            await loadNotes()
                        }
                        showingConflict = false
                        conflictNote = nil
                    },
                    onCancel: {
                        showingConflict = false
                        conflictNote = nil
                    }
                )
                .themed()
            }
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Offline - changes will sync when connected")
                .font(.caption)
            Spacer()
            if appViewModel.pendingCount > 0 {
                Text("\(appViewModel.pendingCount) pending")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(themeColors.accent.opacity(0.2)))
            }
        }
        .foregroundColor(themeColors.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeColors.tertiaryBackground)
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

            // Sync status indicator
            if appViewModel.isSyncing {
                ProgressView()
                    .scaleEffect(0.6)
                    .help("Syncing...")
            } else if appViewModel.hasConflicts {
                Button {
                    showFirstConflict()
                } label: {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Resolve conflicts")
            } else if appViewModel.pendingCount > 0 {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryText)
                    .help("\(appViewModel.pendingCount) pending changes")
            }

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

    private func showFirstConflict() {
        do {
            let conflicts = try dataStore.fetchConflictedNotes()
            if let first = conflicts.first {
                conflictNote = first
                showingConflict = true
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private var notesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Notes are sorted newest first, so reverse for chronological display
                    ForEach(notes.reversed()) { note in
                        HStack(alignment: .top, spacing: 4) {
                            NoteBubbleView(
                                note: note,
                                images: noteImages[note.id] ?? [],
                                onCheckboxToggle: { newText in
                                    Task { await updateNoteText(note: note, newText: newText) }
                                }
                            )

                            // Sync status indicator for each note
                            if let status = noteSyncStatus[note.id], status != .synced {
                                SyncStatusIndicator(status: status)
                                    .padding(.top, 4)
                            }
                        }
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

                            // Show conflict resolution option if this note has a conflict
                            if noteSyncStatus[note.id] == .conflict {
                                Divider()
                                Button {
                                    showConflictForNote(note.id)
                                } label: {
                                    Label("Resolve Conflict", systemImage: "exclamationmark.triangle")
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

    private func showConflictForNote(_ noteId: UUID) {
        do {
            if let localNote = try dataStore.fetchNote(id: noteId), localNote.syncStatus == .conflict {
                conflictNote = localNote
                showingConflict = true
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func startEditing(_ note: Note) {
        editText = note.plainText
        editingNote = note
    }

    private func saveEdit(note: Note, newText: String) async {
        do {
            // Update locally first
            if let updatedLocal = try dataStore.updateLocalNote(
                id: note.id,
                plainText: newText,
                isTodo: note.isTodo,
                isDone: note.isDone
            ) {
                let updatedNote = Note(from: updatedLocal)
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = updatedNote
                }
                noteSyncStatus[note.id] = updatedLocal.syncStatus
            }

            editingNote = nil

            // Try to sync if online
            if appViewModel.isOnline {
                await syncService.syncNote(id: note.id)
                // Reload to get server version
                loadNotesFromLocal()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func toggleTodo(_ note: Note) async {
        do {
            // Update locally first
            if let updatedLocal = try dataStore.updateLocalNote(
                id: note.id,
                plainText: note.plainText,
                isTodo: note.isTodo,
                isDone: !note.isDone
            ) {
                let updatedNote = Note(from: updatedLocal)
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = updatedNote
                }
                noteSyncStatus[note.id] = updatedLocal.syncStatus
            }

            // Try to sync if online
            if appViewModel.isOnline {
                await syncService.syncNote(id: note.id)
                loadNotesFromLocal()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func updateNoteText(note: Note, newText: String) async {
        do {
            // Update locally first
            if let updatedLocal = try dataStore.updateLocalNote(
                id: note.id,
                plainText: newText,
                isTodo: note.isTodo,
                isDone: note.isDone
            ) {
                let updatedNote = Note(from: updatedLocal)
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = updatedNote
                }
                noteSyncStatus[note.id] = updatedLocal.syncStatus
            }

            // Try to sync if online
            if appViewModel.isOnline {
                await syncService.syncNote(id: note.id)
                loadNotesFromLocal()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func deleteNote(_ note: Note) async {
        do {
            // Delete locally first (marks as pending delete if synced)
            try dataStore.deleteNote(id: note.id)
            notes.removeAll { $0.id == note.id }
            noteSyncStatus.removeValue(forKey: note.id)

            // Try to sync deletion if online
            if appViewModel.isOnline {
                await syncService.syncNote(id: note.id)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func loadNotes() async {
        isLoading = notes.isEmpty
        error = nil

        // First load from local storage for instant UI
        loadNotesFromLocal()

        // Then try to fetch from server if online
        guard appViewModel.isOnline else {
            isLoading = false
            return
        }

        do {
            let serverNotes = try await APIService.shared.getNotes(notebookId: notebook.id)

            // Save to local storage and update UI
            for note in serverNotes {
                try dataStore.saveNote(note, syncStatus: .synced)
            }

            // Reload from local to get consistent state
            loadNotesFromLocal()

            // Load images in parallel using TaskGroup
            await withTaskGroup(of: (UUID, [NoteImage]).self) { group in
                for note in notes {
                    group.addTask {
                        do {
                            let images = try await APIService.shared.getNoteImages(noteId: note.id)
                            // Save to local storage
                            for image in images {
                                try? await LocalDataStore.shared.saveNoteImage(image)
                            }
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
            // If we have local data, don't show error
            if notes.isEmpty {
                showError(error.localizedDescription)
            }
            isLoading = false
        }
    }

    private func loadNotesFromLocal() {
        do {
            let localNotes = try dataStore.fetchNotes(notebookId: notebook.id)

            // Convert to Note and track sync status
            notes = localNotes.map { Note(from: $0) }
            noteSyncStatus = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0.syncStatus) })

            // Load local images
            for localNote in localNotes {
                let localImages = try dataStore.fetchImages(noteId: localNote.id)
                noteImages[localNote.id] = localImages.map { NoteImage(from: $0) }
            }

            isLoading = false
        } catch {
            // Silently fail - will try server
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
