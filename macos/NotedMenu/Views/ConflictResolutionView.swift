import SwiftUI

/// View for resolving conflicts between local and server versions of a note
struct ConflictResolutionView: View {
    let localNote: LocalNote
    let onResolve: (Bool) -> Void  // true = keep local, false = keep server
    let onCancel: () -> Void

    @Environment(\.themeColors) var themeColors
    @State private var serverNote: Note?
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Sync Conflict")
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

            Text("This note was modified both locally and on the server. Choose which version to keep:")
                .font(.caption)
                .foregroundColor(themeColors.secondaryText)
                .multilineTextAlignment(.center)

            // Side-by-side comparison
            HStack(alignment: .top, spacing: 12) {
                // Local version
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "laptopcomputer")
                            .foregroundColor(themeColors.accent)
                        Text("Your Version")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(themeColors.text)
                    }

                    Text("Modified: \(localNote.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(themeColors.secondaryText)

                    ScrollView {
                        Text(localNote.plainText)
                            .font(.caption)
                            .foregroundColor(themeColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeColors.tertiaryBackground)
                    )

                    Button {
                        onResolve(true)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Keep Mine")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)

                // Server version
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cloud")
                            .foregroundColor(.blue)
                        Text("Server Version")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(themeColors.text)
                    }

                    if let server = serverNote {
                        Text("Modified: \(server.updatedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundColor(themeColors.secondaryText)

                        ScrollView {
                            Text(server.plainText)
                                .font(.caption)
                                .foregroundColor(themeColors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(themeColors.tertiaryBackground)
                        )
                    } else if let error = loadError {
                        Text("Error loading server version")
                            .font(.caption2)
                            .foregroundColor(.red)

                        Text(error)
                            .font(.caption2)
                            .foregroundColor(themeColors.secondaryText)
                            .frame(height: 120)
                    } else {
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(themeColors.secondaryText)

                        ProgressView()
                            .frame(height: 120)
                    }

                    Button {
                        onResolve(false)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Keep Theirs")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(serverNote == nil || loadError != nil)
                }
                .frame(maxWidth: .infinity)
            }

            // Differences highlight (if available)
            if let server = serverNote {
                DifferenceHighlightView(
                    localText: localNote.plainText,
                    serverText: server.plainText,
                    themeColors: themeColors
                )
            }
        }
        .padding(16)
        .frame(width: 500)
        .background(themeColors.background)
        .task {
            await loadServerVersion()
        }
    }

    private func loadServerVersion() async {
        // Parse server version from conflict JSON
        guard let conflictJSON = localNote.conflictJSON,
              let data = conflictJSON.data(using: .utf8) else {
            loadError = "No conflict data available"
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            serverNote = try decoder.decode(Note.self, from: data)
        } catch {
            loadError = "Failed to parse server version: \(error.localizedDescription)"
        }
    }
}

/// Highlights differences between local and server text
struct DifferenceHighlightView: View {
    let localText: String
    let serverText: String
    let themeColors: ThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Changes")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeColors.secondaryText)

            if localText == serverText {
                Text("No text differences")
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryText)
                    .italic()
            } else {
                HStack(spacing: 8) {
                    VStack(alignment: .leading) {
                        Text("Local")
                            .font(.caption2)
                            .foregroundColor(themeColors.secondaryText)
                        Text("\(localText.count) characters")
                            .font(.caption2)
                            .foregroundColor(themeColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Server")
                            .font(.caption2)
                            .foregroundColor(themeColors.secondaryText)
                        Text("\(serverText.count) characters")
                            .font(.caption2)
                            .foregroundColor(themeColors.secondaryText)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(themeColors.tertiaryBackground)
                )
            }
        }
    }
}

#Preview {
    let localNote = LocalNote(
        id: UUID(),
        notebookId: UUID(),
        plainText: "This is my local version of the note with some changes.",
        contentJSON: "{}",
        syncStatus: .conflict
    )

    return ConflictResolutionView(
        localNote: localNote,
        onResolve: { _ in },
        onCancel: {}
    )
    .themed()
}
