import CoreData
import Foundation

final class LocalDataService {
    static let shared = LocalDataService()

    private let stack = CoreDataStack.shared
    private var context: NSManagedObjectContext { stack.viewContext }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    // MARK: - Notebooks

    func fetchNotebooks() -> [Notebook] {
        let request = NotebookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { toNotebook($0) }
        } catch {
            print("Failed to fetch notebooks: \(error)")
            return []
        }
    }

    func createNotebook(title: String) -> Notebook? {
        let entity = NotebookEntity(context: context)
        let id = UUID()
        let now = Date()

        entity.id = id
        entity.title = title
        entity.createdAt = now
        entity.updatedAt = now
        entity.sortOrder = Int32(fetchNotebooks().count)
        entity.syncStatus = SyncStatus.pending.rawValue
        entity.locallyModifiedAt = now

        stack.save()

        return toNotebook(entity)
    }

    func updateNotebook(id: UUID, title: String? = nil, sortOrder: Int? = nil) -> Notebook? {
        guard let entity = fetchNotebookEntity(id: id) else { return nil }

        if let title = title {
            entity.title = title
        }
        if let sortOrder = sortOrder {
            entity.sortOrder = Int32(sortOrder)
        }

        entity.updatedAt = Date()
        entity.syncStatus = SyncStatus.pending.rawValue
        entity.locallyModifiedAt = Date()

        stack.save()

        return toNotebook(entity)
    }

    func deleteNotebook(id: UUID) {
        guard let entity = fetchNotebookEntity(id: id) else { return }

        // Soft delete for sync
        entity.deletedAt = Date()
        entity.syncStatus = SyncStatus.pending.rawValue
        entity.locallyModifiedAt = Date()

        stack.save()
    }

    // MARK: - Notes

    func fetchNotes(notebookId: UUID) -> [Note] {
        let request = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "notebookId == %@ AND deletedAt == nil", notebookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { toNote($0) }
        } catch {
            print("Failed to fetch notes: \(error)")
            return []
        }
    }

    func createNote(notebookId: UUID, content: String, isTodo: Bool = false) -> Note? {
        let entity = NoteEntity(context: context)
        let id = UUID()
        let now = Date()
        let noteContent = NoteContent.text(content)

        entity.id = id
        entity.notebookId = notebookId
        entity.content = try? encoder.encode(noteContent)
        entity.plainText = content
        entity.isTodo = isTodo
        entity.isDone = false
        entity.version = 1
        entity.createdAt = now
        entity.updatedAt = now
        entity.syncStatus = SyncStatus.pending.rawValue
        entity.locallyModifiedAt = now

        stack.save()

        return toNote(entity)
    }

    func updateNote(id: UUID, content: String? = nil, isTodo: Bool? = nil, isDone: Bool? = nil, reminderAt: Date?? = nil) -> Note? {
        guard let entity = fetchNoteEntity(id: id) else { return nil }

        if let content = content {
            let noteContent = NoteContent.text(content)
            entity.content = try? encoder.encode(noteContent)
            entity.plainText = content
        }
        if let isTodo = isTodo {
            entity.isTodo = isTodo
        }
        if let isDone = isDone {
            entity.isDone = isDone
        }
        // Use double optional to distinguish "not provided" from "set to nil"
        if let reminder = reminderAt {
            entity.reminderAt = reminder
        }

        entity.updatedAt = Date()
        entity.version += 1
        entity.syncStatus = SyncStatus.pending.rawValue
        entity.locallyModifiedAt = Date()

        stack.save()

        return toNote(entity)
    }

    func deleteNote(id: UUID) {
        guard let entity = fetchNoteEntity(id: id) else { return }

        // Soft delete for sync
        entity.deletedAt = Date()
        entity.syncStatus = SyncStatus.pending.rawValue
        entity.locallyModifiedAt = Date()

        stack.save()
    }

    // MARK: - Sync Helpers

    func getPendingChanges() -> PendingChanges {
        var changes = PendingChanges()

        // Notebooks
        let notebookRequest = NotebookEntity.fetchRequest()
        notebookRequest.predicate = NSPredicate(format: "syncStatus == %d", SyncStatus.pending.rawValue)

        if let notebooks = try? context.fetch(notebookRequest) {
            for entity in notebooks {
                if let notebook = toNotebook(entity) {
                    if entity.deletedAt != nil {
                        changes.deletedNotebookIds.append(notebook.id)
                    } else if entity.serverVersion == 0 {
                        changes.createdNotebooks.append(notebook)
                    } else {
                        changes.updatedNotebooks.append(notebook)
                    }
                }
            }
        }

        // Notes
        let noteRequest = NoteEntity.fetchRequest()
        noteRequest.predicate = NSPredicate(format: "syncStatus == %d", SyncStatus.pending.rawValue)

        if let notes = try? context.fetch(noteRequest) {
            for entity in notes {
                if let note = toNote(entity) {
                    if entity.deletedAt != nil {
                        changes.deletedNoteIds.append(note.id)
                    } else if entity.serverVersion == 0 {
                        changes.createdNotes.append(note)
                    } else {
                        changes.updatedNotes.append(note)
                    }
                }
            }
        }

        return changes
    }

    func markAsSynced(notebookIds: [UUID], noteIds: [UUID]) {
        for id in notebookIds {
            if let entity = fetchNotebookEntity(id: id) {
                entity.syncStatus = SyncStatus.synced.rawValue
                entity.locallyModifiedAt = nil
            }
        }

        for id in noteIds {
            if let entity = fetchNoteEntity(id: id) {
                entity.syncStatus = SyncStatus.synced.rawValue
                entity.locallyModifiedAt = nil
            }
        }

        stack.save()
    }

    func mergeRemoteNotebooks(_ notebooks: [Notebook]) {
        for notebook in notebooks {
            if let entity = fetchNotebookEntity(id: notebook.id) {
                // Update existing
                if entity.syncStatus != SyncStatus.pending.rawValue {
                    entity.title = notebook.title
                    entity.sortOrder = Int32(notebook.sortOrder)
                    entity.updatedAt = notebook.updatedAt
                    entity.deletedAt = notebook.deletedAt
                }
            } else {
                // Create new
                let entity = NotebookEntity(context: context)
                entity.id = notebook.id
                entity.title = notebook.title
                entity.sortOrder = Int32(notebook.sortOrder)
                entity.createdAt = notebook.createdAt
                entity.updatedAt = notebook.updatedAt
                entity.deletedAt = notebook.deletedAt
                entity.syncStatus = SyncStatus.synced.rawValue
            }
        }

        stack.save()
    }

    func mergeRemoteNotes(_ notes: [Note]) {
        for note in notes {
            if let entity = fetchNoteEntity(id: note.id) {
                // Update existing
                if entity.syncStatus != SyncStatus.pending.rawValue {
                    entity.content = try? encoder.encode(note.content)
                    entity.plainText = note.plainText
                    entity.isTodo = note.isTodo
                    entity.isDone = note.isDone
                    entity.reminderAt = note.reminderAt
                    entity.version = Int32(note.version)
                    entity.updatedAt = note.updatedAt
                    entity.deletedAt = note.deletedAt
                }
            } else {
                // Create new
                let entity = NoteEntity(context: context)
                entity.id = note.id
                entity.notebookId = note.notebookId
                entity.content = try? encoder.encode(note.content)
                entity.plainText = note.plainText
                entity.isTodo = note.isTodo
                entity.isDone = note.isDone
                entity.reminderAt = note.reminderAt
                entity.version = Int32(note.version)
                entity.createdAt = note.createdAt
                entity.updatedAt = note.updatedAt
                entity.deletedAt = note.deletedAt
                entity.syncStatus = SyncStatus.synced.rawValue
            }
        }

        stack.save()
    }

    func removeDeletedItems(notebookIds: [UUID], noteIds: [UUID]) {
        for id in notebookIds {
            if let entity = fetchNotebookEntity(id: id) {
                context.delete(entity)
            }
        }

        for id in noteIds {
            if let entity = fetchNoteEntity(id: id) {
                context.delete(entity)
            }
        }

        stack.save()
    }

    func clearAllData() {
        stack.clearAllData()
    }

    // MARK: - Private Helpers

    private func fetchNotebookEntity(id: UUID) -> NotebookEntity? {
        let request = NotebookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchNoteEntity(id: UUID) -> NoteEntity? {
        let request = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func toNotebook(_ entity: NotebookEntity) -> Notebook? {
        guard let id = entity.id,
              let title = entity.title,
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt else {
            return nil
        }

        return Notebook(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: entity.deletedAt,
            sortOrder: Int(entity.sortOrder)
        )
    }

    private func toNote(_ entity: NoteEntity) -> Note? {
        guard let id = entity.id,
              let notebookId = entity.notebookId,
              let contentData = entity.content,
              let plainText = entity.plainText,
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt else {
            return nil
        }

        let content = (try? decoder.decode(NoteContent.self, from: contentData)) ?? .text(plainText)

        return Note(
            id: id,
            notebookId: notebookId,
            content: content,
            plainText: plainText,
            isTodo: entity.isTodo,
            isDone: entity.isDone,
            reminderAt: entity.reminderAt,
            version: Int(entity.version),
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: entity.deletedAt
        )
    }
}
