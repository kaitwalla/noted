import SwiftUI

struct NotebookListView: View {
    @State private var viewModel = NotebooksViewModel()
    @State private var showCreateSheet = false
    @State private var newNotebookTitle = ""
    @State private var editingNotebook: Notebook?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.notebooks.isEmpty {
                    ProgressView("Loading notebooks...")
                } else if viewModel.notebooks.isEmpty {
                    ContentUnavailableView(
                        "No Notebooks",
                        systemImage: "book.closed",
                        description: Text("Create a notebook to get started")
                    )
                } else {
                    List {
                        ForEach(viewModel.notebooks) { notebook in
                            NavigationLink {
                                NoteTimelineView(notebook: notebook)
                            } label: {
                                NotebookRow(notebook: notebook)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteNotebook(notebook.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingNotebook = notebook
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.fetchNotebooks()
                    }
                }
            }
            .navigationTitle("Notebooks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
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
            .sheet(isPresented: $showCreateSheet) {
                CreateNotebookSheet(
                    title: $newNotebookTitle,
                    onCreate: {
                        Task {
                            await viewModel.createNotebook(title: newNotebookTitle)
                            newNotebookTitle = ""
                            showCreateSheet = false
                        }
                    }
                )
            }
            .sheet(item: $editingNotebook) { notebook in
                EditNotebookSheet(
                    notebook: notebook,
                    onSave: { newTitle in
                        Task {
                            await viewModel.updateNotebook(notebook.id, title: newTitle)
                            editingNotebook = nil
                        }
                    }
                )
            }
            .task {
                await viewModel.fetchNotebooks()
            }
        }
    }
}

struct CreateNotebookSheet: View {
    @Binding var title: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Notebook Title", text: $title)
            }
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        title = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct EditNotebookSheet: View {
    let notebook: Notebook
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Notebook Title", text: $title)
            }
            .navigationTitle("Edit Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                title = notebook.title
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NotebookListView()
}
