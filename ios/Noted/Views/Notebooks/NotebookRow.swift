import SwiftUI

struct NotebookRow: View {
    let notebook: Notebook

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(notebook.title)
                    .font(.body)

                Text(formatDate(notebook.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    List {
        NotebookRow(notebook: Notebook(
            id: UUID(),
            title: "Work Notes",
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            sortOrder: 0
        ))
        NotebookRow(notebook: Notebook(
            id: UUID(),
            title: "Personal Ideas",
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-3600),
            deletedAt: nil,
            sortOrder: 1
        ))
    }
}
