import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                }

                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Notes",
                        systemImage: "magnifyingglass",
                        description: Text("Enter text to search across all notebooks")
                    )
                } else if viewModel.results.isEmpty && !viewModel.isSearching {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No notes found matching \"\(searchText)\"")
                    )
                } else {
                    List {
                        ForEach(viewModel.results) { result in
                            NavigationLink {
                                if let notebook = viewModel.notebooks.first(where: { $0.id == result.notebookId }) {
                                    NoteTimelineView(notebook: notebook)
                                }
                            } label: {
                                SearchResultRow(result: result, query: searchText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search notes...")
            .onChange(of: searchText) { _, newValue in
                viewModel.search(query: newValue)
            }
            .task {
                viewModel.loadNotebooks()
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Notebook name
            HStack {
                Image(systemName: "book.closed.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.notebookTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Note content with highlighted match
            Text(highlightedText)
                .lineLimit(3)

            // Date
            Text(formatDate(result.createdAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var highlightedText: AttributedString {
        var attributedString = AttributedString(result.content)

        if let range = attributedString.range(of: query, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .yellow.opacity(0.3)
            attributedString[range].font = .body.bold()
        }

        return attributedString
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    SearchView()
}
