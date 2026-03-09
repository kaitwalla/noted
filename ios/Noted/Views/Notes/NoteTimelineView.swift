import SwiftUI
import UIKit

struct NoteTimelineView: View {
    let notebook: Notebook
    @Environment(\.themeColors) private var colors
    @State private var viewModel: NotesViewModel
    @State private var imagesViewModel = ImagesViewModel()
    @State private var noteImages: [UUID: [NoteImage]] = [:]
    @State private var noteImageLoadOrder: [UUID] = [] // Track order for LRU eviction
    @State private var scrollToBottom = false

    private let maxCachedNoteImages = 30 // Limit memory usage (reduced from 50)

    // Cached date formatter to avoid recreating in render loops
    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    init(notebook: Notebook) {
        self.notebook = notebook
        self._viewModel = State(initialValue: NotesViewModel(notebookId: notebook.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Notes list or empty state
            if viewModel.notes.isEmpty && !viewModel.isLoading {
                EmptyStateView.noNotes
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(groupedUnstarredNotes, id: \.date) { group in
                                Section {
                                    ForEach(group.notes) { note in
                                        noteBubble(for: note)
                                    }
                                } header: {
                                    Text(formatSectionDate(group.date))
                                        .font(.caption)
                                        .foregroundStyle(colors.secondaryText)
                                        .padding(.top, 8)
                                }
                            }

                            // Starred notes pinned at bottom
                            if !starredNotes.isEmpty {
                                Section {
                                    ForEach(starredNotes) { note in
                                        noteBubble(for: note)
                                    }
                                } header: {
                                    Text("Starred")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                        .padding(.top, 8)
                                }
                            }

                            // Invisible anchor for scrolling to bottom
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding()
                        .animation(.easeInOut(duration: 0.3), value: viewModel.notes.count)
                    }
                    .onChange(of: viewModel.notes.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: scrollToBottom) { _, newValue in
                        if newValue {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                            scrollToBottom = false
                        }
                    }
                    .refreshable {
                        await viewModel.fetchNotes()
                    }
                }
            }

            // Upload progress indicator
            if imagesViewModel.isUploading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Uploading image...")
                        .font(.caption)
                        .foregroundStyle(colors.secondaryText)
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Note input
            NoteInputView(
                onSend: { content in
                    Task {
                        await viewModel.createNote(content: content)
                        scrollToBottom = true
                    }
                },
                onImageSelected: { image, keepFullSize in
                    // Create note for the image with marker content
                    Task {
                        if let note = await viewModel.createNoteAndReturn(content: "[image]") {
                            await uploadImage(image, noteId: note.id, keepFullSize: keepFullSize)
                            scrollToBottom = true
                        }
                    }
                }
            )
        }
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay {
            if viewModel.isLoading && viewModel.notes.isEmpty {
                ProgressView()
            }
        }
        .task {
            await viewModel.fetchNotes()
            scrollToBottom = true
        }
        .onDisappear {
            // Clear image cache when leaving view to free memory
            noteImages.removeAll()
            noteImageLoadOrder.removeAll()
        }
    }

    private func fetchImagesForNote(_ noteId: UUID) async {
        guard noteImages[noteId] == nil else { return }

        do {
            let images = try await ImageService.shared.fetchImages(noteId: noteId)
            await MainActor.run {
                // LRU eviction: remove oldest entries if at or over limit
                // Remove half of cache when full to reduce eviction frequency
                if noteImages.count >= maxCachedNoteImages {
                    let removeCount = maxCachedNoteImages / 2
                    let toRemove = noteImageLoadOrder.prefix(removeCount)
                    for id in toRemove {
                        noteImages.removeValue(forKey: id)
                    }
                    noteImageLoadOrder.removeFirst(min(removeCount, noteImageLoadOrder.count))
                }

                noteImages[noteId] = images
                noteImageLoadOrder.append(noteId)
            }
        } catch {
            #if DEBUG
            print("Failed to fetch images for note \(noteId): \(error.localizedDescription)")
            #endif
        }
    }

    private func uploadImage(_ image: UIImage, noteId: UUID, keepFullSize: Bool = false) async {
        if let noteImage = await imagesViewModel.uploadImage(image, noteId: noteId, keepFullSize: keepFullSize) {
            await MainActor.run {
                var images = noteImages[noteId] ?? []
                images.append(noteImage)
                noteImages[noteId] = images
            }
        }
    }

    @ViewBuilder
    private func noteBubble(for note: Note) -> some View {
        NoteBubble(
            note: note,
            images: noteImages[note.id] ?? [],
            onEdit: { content in
                Task {
                    await viewModel.updateNote(note.id, content: content)
                }
            },
            onDelete: {
                Task {
                    await viewModel.deleteNote(note.id)
                }
            },
            onToggleStarred: {
                Task {
                    await viewModel.toggleStarred(note.id)
                }
            },
            onContentChanged: { newContent, newPlainText in
                Task {
                    await viewModel.updateNoteContent(note.id, content: newContent, plainText: newPlainText)
                }
            }
        )
        .id(note.id)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .opacity
        ))
        .task {
            await fetchImagesForNote(note.id)
        }
    }

    private var starredNotes: [Note] {
        viewModel.notes.filter { $0.isStarred }
    }

    // Group unstarred notes by date
    private var groupedUnstarredNotes: [NoteGroup] {
        let calendar = Calendar.current
        let unstarred = viewModel.notes.filter { !$0.isStarred }
        let grouped = Dictionary(grouping: unstarred) { note in
            calendar.startOfDay(for: note.createdAt)
        }

        return grouped.map { NoteGroup(date: $0.key, notes: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.sectionDateFormatter.string(from: date)
        }
    }
}

struct NoteGroup {
    let date: Date
    let notes: [Note]
}

#Preview {
    NavigationStack {
        NoteTimelineView(notebook: Notebook(
            id: UUID(),
            title: "Test Notebook",
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            sortOrder: 0
        ))
    }
}
