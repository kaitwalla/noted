import Foundation
import Observation

@Observable
final class TodosViewModel {
    var todos: [TodoItem] = []
    var notebooks: [Notebook] = []
    var isLoading = false
    var errorMessage: String?

    private let localData = LocalDataService.shared
    private let notesService = NotesService.shared
    private let networkMonitor = NetworkMonitor.shared

    @MainActor
    func fetchTodos() async {
        isLoading = true
        errorMessage = nil

        // Fetch notebooks first
        notebooks = localData.fetchNotebooks()

        // Fetch all notes and filter to todos
        var allTodos: [TodoItem] = []
        for notebook in notebooks {
            let notes = localData.fetchNotes(notebookId: notebook.id)
            let todoNotes = notes.filter { $0.isTodo }
            allTodos.append(contentsOf: todoNotes.map { note in
                TodoItem(
                    id: note.id,
                    notebookId: note.notebookId,
                    content: note.plainText,
                    isDone: note.isDone,
                    createdAt: note.createdAt
                )
            })
        }

        todos = allTodos.sorted { $0.createdAt > $1.createdAt }
        isLoading = false
    }

    @MainActor
    func toggleTodo(_ id: UUID) async {
        guard let todo = todos.first(where: { $0.id == id }) else { return }

        // Update locally
        if let _ = localData.updateNote(id: id, isDone: !todo.isDone) {
            if let index = todos.firstIndex(where: { $0.id == id }) {
                todos[index] = TodoItem(
                    id: todo.id,
                    notebookId: todo.notebookId,
                    content: todo.content,
                    isDone: !todo.isDone,
                    createdAt: todo.createdAt
                )
            }
        }

        // Sync in background
        if networkMonitor.isConnected {
            Task {
                try? await SyncService.shared.sync()
            }
        }
    }
}
