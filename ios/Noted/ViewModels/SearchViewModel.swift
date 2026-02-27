import Foundation
import Observation
import Combine

@Observable
final class SearchViewModel {
    var results: [SearchResult] = []
    var notebooks: [Notebook] = []
    var isSearching = false

    private let localData = LocalDataService.shared
    private var searchTask: Task<Void, Never>?

    func loadNotebooks() {
        notebooks = localData.fetchNotebooks()
    }

    func search(query: String) {
        // Cancel previous search
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            guard !Task.isCancelled else { return }

            await performSearch(query: trimmedQuery)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        var searchResults: [SearchResult] = []

        for notebook in notebooks {
            let notes = localData.fetchNotes(notebookId: notebook.id)

            for note in notes {
                if note.plainText.localizedCaseInsensitiveContains(query) {
                    searchResults.append(SearchResult(
                        id: note.id,
                        notebookId: notebook.id,
                        notebookTitle: notebook.title,
                        content: note.plainText,
                        createdAt: note.createdAt
                    ))
                }
            }
        }

        results = searchResults.sorted { $0.createdAt > $1.createdAt }
        isSearching = false
    }
}

struct SearchResult: Identifiable {
    let id: UUID
    let notebookId: UUID
    let notebookTitle: String
    let content: String
    let createdAt: Date
}
