import CoreData

/// Modern `NSPersistentContainer` over the existing `OSTDataModel` CoreData model.
/// Production points at the same sqlite store MagicalRecord created (Application
/// Support / "OSTDataModel"), so existing on-device data is preserved during the
/// incremental migration. Tests use an in-memory store.
final class CoreDataStack {
    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext { container.viewContext }

    /// MagicalRecord was set up with `setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"OSTDataModel"`.
    init(inMemory: Bool = false, storeName: String = "OSTDataModel") {
        let bundles = [Bundle.main, Bundle(for: CoreDataStack.self)]
        guard let model = bundles.lazy
                .compactMap({ $0.url(forResource: "OSTDataModel", withExtension: "momd") })
                .compactMap({ NSManagedObjectModel(contentsOf: $0) })
                .first else {
            fatalError("OSTDataModel.momd not found in app bundle")
        }
        container = NSPersistentContainer(name: "OSTDataModel", managedObjectModel: model)

        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let desc = NSPersistentStoreDescription(url: appSupport.appendingPathComponent(storeName))
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [desc]
        }

        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData load failed: \(error)") }
        }
    }
}
