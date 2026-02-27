import CoreData
import Foundation

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    private init() {
        container = NSPersistentContainer(name: "Noted")

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error.localizedDescription)")
        }
    }

    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear All Data (for logout)

    func clearAllData() {
        let entities = container.managedObjectModel.entities

        for entity in entities {
            guard let entityName = entity.name else { continue }
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try container.persistentStoreCoordinator.execute(deleteRequest, with: viewContext)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }

        viewContext.reset()
    }
}

// MARK: - Sync Status

enum SyncStatus: Int16 {
    case synced = 0
    case pending = 1
    case conflict = 2
}
