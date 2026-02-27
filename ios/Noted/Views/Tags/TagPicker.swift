import SwiftUI

struct TagPicker: View {
    @Binding var selectedTags: Set<UUID>
    @State private var viewModel = TagsViewModel()
    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#4A7AE5"
    @Environment(\.dismiss) private var dismiss

    let availableColors = [
        "#FF5733", "#33A1FF", "#33FF57", "#FF33A1",
        "#FFD700", "#9B59B6", "#1ABC9C", "#E74C3C",
        "#3498DB", "#2ECC71", "#F39C12", "#8E44AD"
    ]

    var body: some View {
        NavigationStack {
            List {
                // Existing tags
                Section("Tags") {
                    if viewModel.tags.isEmpty && !viewModel.isLoading {
                        Text("No tags yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.tags) { tag in
                            Button {
                                toggleTag(tag.id)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(tag.swiftUIColor)
                                        .frame(width: 12, height: 12)

                                    Text(tag.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedTags.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                // Create new tag
                Section {
                    Button {
                        showCreateTag = true
                    } label: {
                        Label("Create New Tag", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.fetchTags()
            }
            .sheet(isPresented: $showCreateTag) {
                CreateTagSheet(
                    name: $newTagName,
                    color: $newTagColor,
                    availableColors: availableColors,
                    onCreate: {
                        Task {
                            await viewModel.createTag(name: newTagName, color: newTagColor)
                            newTagName = ""
                            showCreateTag = false
                        }
                    }
                )
            }
        }
    }

    private func toggleTag(_ id: UUID) {
        if selectedTags.contains(id) {
            selectedTags.remove(id)
        } else {
            selectedTags.insert(id)
        }
    }
}

struct CreateTagSheet: View {
    @Binding var name: String
    @Binding var color: String
    let availableColors: [String]
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableColors, id: \.self) { colorHex in
                            Button {
                                color = colorHex
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if color == colorHex {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .fontWeight(.bold)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Preview") {
                    HStack {
                        Spacer()
                        TagChip(tag: Tag(
                            id: UUID(),
                            name: name.isEmpty ? "Tag" : name,
                            color: color,
                            createdAt: Date()
                        ))
                        Spacer()
                    }
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TagPicker(selectedTags: .constant([]))
}
