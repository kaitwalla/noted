import SwiftUI

struct TodosView: View {
    @State private var viewModel = TodosViewModel()
    @State private var filter: TodoFilter = .pending

    enum TodoFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case completed = "Completed"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filter", selection: $filter) {
                    ForEach(TodoFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Todos list
                if viewModel.isLoading && viewModel.todos.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredTodos.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "checkmark.circle",
                        description: Text(emptyDescription)
                    )
                } else {
                    List {
                        ForEach(groupedTodos, id: \.notebook.id) { group in
                            Section(group.notebook.title) {
                                ForEach(group.todos) { todo in
                                    TodoRow(
                                        todo: todo,
                                        onToggle: {
                                            Task {
                                                await viewModel.toggleTodo(todo.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.fetchTodos()
                    }
                }
            }
            .navigationTitle("Todos")
            .task {
                await viewModel.fetchTodos()
            }
        }
    }

    private var filteredTodos: [TodoItem] {
        switch filter {
        case .all:
            return viewModel.todos
        case .pending:
            return viewModel.todos.filter { !$0.isDone }
        case .completed:
            return viewModel.todos.filter { $0.isDone }
        }
    }

    private var groupedTodos: [TodoGroup] {
        let grouped = Dictionary(grouping: filteredTodos) { $0.notebookId }
        return grouped.compactMap { notebookId, todos in
            guard let notebook = viewModel.notebooks.first(where: { $0.id == notebookId }) else {
                return nil
            }
            return TodoGroup(notebook: notebook, todos: todos)
        }.sorted { $0.notebook.title < $1.notebook.title }
    }

    private var emptyTitle: String {
        switch filter {
        case .all: return "No Todos"
        case .pending: return "All Done!"
        case .completed: return "No Completed Todos"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all: return "Create a note and mark it as a todo"
        case .pending: return "You've completed all your todos"
        case .completed: return "Complete some todos to see them here"
        }
    }
}

struct TodoGroup {
    let notebook: Notebook
    let todos: [TodoItem]
}

struct TodoItem: Identifiable {
    let id: UUID
    let notebookId: UUID
    let content: String
    let isDone: Bool
    let createdAt: Date
}

struct TodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isDone ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.content)
                        .strikethrough(todo.isDone)
                        .foregroundStyle(todo.isDone ? .secondary : .primary)
                        .lineLimit(2)

                    Text(formatDate(todo.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    TodosView()
}
