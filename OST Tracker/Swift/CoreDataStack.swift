import CoreData

/// Modern `NSPersistentContainer` over the existing `OSTDataModel` CoreData model.
/// Production points at the same sqlite store MagicalRecord created (Application
/// Support / "OSTDataModel"), so existing on-device data is preserved during the
/// incremental migration. Tests use an in-memory store.
final class CoreDataStack {

    /// The app-wide stack. Created lazily on first use (AppDelegate bootstraps it at
    /// launch). The MagicalRecord-compatibility shim routes every `mr_*` call here.
    /// `var` so tests can point it at a temporary on-disk store.
    static var shared = CoreDataStack()

    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext { container.viewContext }

    /// MagicalRecord was set up with `setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"OSTDataModel"`.
    /// `storeURL` overrides the on-disk location (tests); production leaves it nil.
    init(inMemory: Bool = false, storeName: String = "OSTDataModel", storeURL: URL? = nil) {
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
            // MagicalRecord stored the sqlite file under an app-name subdirectory:
            // `Application Support/<CFBundleName>/OSTDataModel` (e.g. ".../OST Remote/OSTDataModel").
            // Point at the exact same path so existing on-device data is preserved.
            let url: URL
            if let storeURL = storeURL {
                url = storeURL
            } else {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                let appName = (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? storeName
                let storeDir = appSupport.appendingPathComponent(appName, isDirectory: true)
                try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
                url = storeDir.appendingPathComponent(storeName)
            }

            let desc = NSPersistentStoreDescription(url: url)
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [desc]
        }

        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData load failed: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }
}
