//
//  MagicalRecordShim.swift
//  OST Tracker
//
//  Drop-in replacement for the handful of MagicalRecord selectors the app still
//  uses, implemented on the native `CoreDataStack`. Keeping the exact `mr_*`/`MR_*`
//  selector names means the existing call sites (Swift and Obj-C) stay unchanged
//  while MagicalRecord itself is removed as a dependency.
//
//  Only the API surface actually called by this app is reimplemented:
//    • NSManagedObject (class):  mr_createEntity, mr_findFirst(with:), mr_findAll(with:),
//                                mr_findAllSorted(by:ascending:with:), mr_import(from:[in:]),
//                                MR_findFirst, MR_findAllWithPredicate:, MR_truncateAll
//    • NSManagedObject (inst.):  mr_deleteEntity
//    • NSManagedObjectContext:   mr_default()/MR_defaultContext,
//                                mr_saveOnlySelfAndWait()/MR_saveOnlySelfAndWait,
//                                mr_context(withParent:)
//
//  `mr_import` replicates MagicalRecord's dictionary→entity mapping for the two
//  imported entities (EventModel, EffortModel) using the model's `mappedKeyName`,
//  `relatedByAttribute` and `dateFormat` userInfo keys.
//

import Foundation
import CoreData

/// Obj-C entry point used by AppDelegate to bring up the stack at launch
/// (replaces `[MagicalRecord setupCoreDataStack…]`).
@objc(OSTCoreData)
final class OSTCoreData: NSObject {
    /// Initializes the shared Core Data stack (loads the on-disk store synchronously).
    @objc static func bootstrap() {
        _ = CoreDataStack.shared
    }
}

// MARK: - The default (main) context

extension NSManagedObjectContext {

    @objc(mr_default)
    class func mr_default() -> NSManagedObjectContext {
        return CoreDataStack.shared.viewContext
    }

    @objc(MR_defaultContext)
    class func mrUpperDefaultContext() -> NSManagedObjectContext {
        return CoreDataStack.shared.viewContext
    }

    @objc(mr_saveOnlySelfAndWait)
    func mr_saveOnlySelfAndWait() {
        performAndWait {
            guard hasChanges else { return }
            do { try save() }
            catch { NSLog("[CoreData] save failed: \(error)") }
        }
    }

    @objc(MR_saveOnlySelfAndWait)
    func mrUpperSaveOnlySelfAndWait() {
        mr_saveOnlySelfAndWait()
    }

    /// A child context fed by `parent`. Matches the one call site, which imports
    /// transient picker objects on the main thread, so it is a main-queue child.
    @objc(mr_contextWithParent:)
    class func mr_context(withParent parent: NSManagedObjectContext) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = parent
        return context
    }
}

// MARK: - Finders / create / delete / import

extension NSManagedObject {

    @objc(mr_createEntity)
    class func mr_createEntity() -> Any? {
        let context = CoreDataStack.shared.viewContext
        guard let name = mrEntityName(in: context) else { return nil }
        return NSEntityDescription.insertNewObject(forEntityName: name, into: context)
    }

    @objc(mr_deleteEntity)
    func mr_deleteEntity() {
        (managedObjectContext ?? CoreDataStack.shared.viewContext).delete(self)
    }

    @objc(mr_findFirstWithPredicate:)
    class func mr_findFirst(with predicate: NSPredicate?) -> Any? {
        return mrFetch(predicate: predicate, sort: nil, limit: 1).first
    }

    @objc(MR_findFirst)
    class func mrUpperFindFirst() -> Any? {
        return mr_findFirst(with: nil)
    }

    @objc(mr_findAllWithPredicate:)
    class func mr_findAll(with predicate: NSPredicate?) -> [Any]? {
        return mrFetch(predicate: predicate, sort: nil, limit: 0)
    }

    @objc(MR_findAllWithPredicate:)
    class func mrUpperFindAll(with predicate: NSPredicate?) -> [Any]? {
        return mr_findAll(with: predicate)
    }

    @objc(mr_findAllSortedBy:ascending:withPredicate:)
    class func mr_findAllSorted(by sortTerm: String,
                                ascending: Bool,
                                with predicate: NSPredicate?) -> [Any]? {
        let sort = sortTerm
            .split(separator: ",")
            .map { NSSortDescriptor(key: $0.trimmingCharacters(in: .whitespaces), ascending: ascending) }
        return mrFetch(predicate: predicate, sort: sort, limit: 0)
    }

    @objc(MR_truncateAll)
    class func mrTruncateAll() {
        let context = CoreDataStack.shared.viewContext
        for object in mrFetch(predicate: nil, sort: nil, limit: 0) {
            if let managed = object as? NSManagedObject { context.delete(managed) }
        }
    }

    @objc(mr_importFromObject:)
    class func mr_import(from object: Any?) -> Any? {
        return mr_import(from: object, in: CoreDataStack.shared.viewContext)
    }

    @objc(mr_importFromObject:inContext:)
    class func mr_import(from object: Any?, in context: NSManagedObjectContext?) -> Any? {
        let context = context ?? CoreDataStack.shared.viewContext
        guard let source = object as? [String: Any],
              let entity = mrEntityDescription(in: context) else { return nil }

        let managed = mrFindOrCreate(entity: entity, from: source, in: context)
        for (name, attribute) in entity.attributesByName {
            let key = (attribute.userInfo?["mappedKeyName"] as? String) ?? name
            guard let raw = mrValue(forKeyPath: key, in: source),
                  let value = mrConvert(raw, for: attribute) else { continue }
            managed.setValue(value, forKey: name)
        }
        return managed
    }

    /// Reconciles this entity's table against a JSON:API `included` array.
    /// Upserts every member whose `type` equals `type` (by the entity's
    /// `relatedByAttribute`, via `mr_import`), then deletes any existing row whose
    /// primary key is absent from that set — i.e. rows removed on the server.
    /// No-ops when no member matches `type`, so a partial or malformed response
    /// can't wipe the table.
    ///
    /// Pruning matches server vs. stored keys by their `String(describing:)` form,
    /// so this is only reliable for String-keyed entities (e.g. `EffortModel` →
    /// `effortId`). Numeric primary keys could stringify asymmetrically.
    @objc(mr_reconcileFromIncluded:ofType:)
    class func mr_reconcile(fromIncluded included: [[String: Any]], ofType type: String) {
        let members = included.filter { ($0["type"] as? String) == type }
        guard !members.isEmpty else { return }

        let context = CoreDataStack.shared.viewContext
        guard let entity = mrEntityDescription(in: context),
              let primaryKey = entity.userInfo?["relatedByAttribute"] as? String,
              let primaryAttr = entity.attributesByName[primaryKey] else { return }
        let mappedKey = (primaryAttr.userInfo?["mappedKeyName"] as? String) ?? primaryKey

        var serverKeys = Set<String>()
        for object in members {
            if let raw = mrValue(forKeyPath: mappedKey, in: object),
               let value = mrConvert(raw, for: primaryAttr) {
                serverKeys.insert(String(describing: value))
            }
            _ = mr_import(from: object)
        }

        for case let managed as NSManagedObject in mrFetch(predicate: nil, sort: nil, limit: 0) {
            let key = managed.value(forKey: primaryKey).map { String(describing: $0) }
            if key == nil || !serverKeys.contains(key!) {
                context.delete(managed)
            }
        }

        context.processPendingChanges()
        NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()
    }

    // MARK: - Private helpers

    /// Upsert by the entity's `relatedByAttribute` (the import primary key), mirroring
    /// MagicalRecord. Falls back to insert when the entity declares no related attribute.
    private class func mrFindOrCreate(entity: NSEntityDescription,
                                      from source: [String: Any],
                                      in context: NSManagedObjectContext) -> NSManagedObject {
        if let entityName = entity.name,
           let primaryKey = entity.userInfo?["relatedByAttribute"] as? String,
           let primaryAttr = entity.attributesByName[primaryKey] {
            let mappedKey = (primaryAttr.userInfo?["mappedKeyName"] as? String) ?? primaryKey
            if let raw = mrValue(forKeyPath: mappedKey, in: source),
               let value = mrConvert(raw, for: primaryAttr) {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                request.predicate = NSPredicate(format: "%K == %@", primaryKey, value as! CVarArg)
                request.fetchLimit = 1
                if let existing = (try? context.fetch(request))?.first {
                    return existing
                }
            }
        }
        return NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: context)
    }

    private class func mrFetch(predicate: NSPredicate?,
                               sort: [NSSortDescriptor]?,
                               limit: Int) -> [Any] {
        let context = CoreDataStack.shared.viewContext
        guard let name = mrEntityName(in: context) else { return [] }
        let request = NSFetchRequest<NSManagedObject>(entityName: name)
        request.predicate = predicate
        request.sortDescriptors = sort
        if limit > 0 { request.fetchLimit = limit }
        return (try? context.fetch(request)) ?? []
    }

    private class func mrEntityDescription(in context: NSManagedObjectContext) -> NSEntityDescription? {
        let className = NSStringFromClass(self)
        let model = context.persistentStoreCoordinator?.managedObjectModel
            ?? CoreDataStack.shared.container.managedObjectModel
        return model.entities.first { $0.managedObjectClassName == className }
    }

    private class func mrEntityName(in context: NSManagedObjectContext) -> String? {
        return mrEntityDescription(in: context)?.name
    }
}

// MARK: - Value mapping

/// Resolves a dot-separated key path (e.g. "attributes.startTime") in a JSON dictionary.
private func mrValue(forKeyPath keyPath: String, in source: [String: Any]) -> Any? {
    var current: Any? = source
    for key in keyPath.split(separator: ".") {
        guard let dict = current as? [String: Any] else { return nil }
        current = dict[String(key)]
    }
    if current is NSNull { return nil }
    return current
}

/// Converts a raw JSON value to the Core Data attribute's storage type, mirroring
/// MagicalRecord's coercion (decimals, integers, booleans, formatted dates, transformables).
private func mrConvert(_ raw: Any, for attribute: NSAttributeDescription) -> Any? {
    if raw is NSNull { return nil }

    switch attribute.attributeType {
    case .stringAttributeType:
        if let string = raw as? String { return string }
        if let number = raw as? NSNumber { return number.stringValue }
        return String(describing: raw)

    case .decimalAttributeType:
        if let number = raw as? NSNumber { return NSDecimalNumber(decimal: number.decimalValue) }
        if let string = raw as? String { return NSDecimalNumber(string: string) }
        return nil

    case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
        if let number = raw as? NSNumber { return number }
        if let string = raw as? String, let value = Int(string) { return NSNumber(value: value) }
        return nil

    case .doubleAttributeType, .floatAttributeType:
        if let number = raw as? NSNumber { return number }
        if let string = raw as? String, let value = Double(string) { return NSNumber(value: value) }
        return nil

    case .booleanAttributeType:
        if let number = raw as? NSNumber { return number }
        if let bool = raw as? Bool { return NSNumber(value: bool) }
        if let string = raw as? String { return NSNumber(value: (string as NSString).boolValue) }
        return nil

    case .dateAttributeType:
        if let date = raw as? Date { return date }
        guard let string = raw as? String else { return nil }
        let format = (attribute.userInfo?["dateFormat"] as? String) ?? "yyyy-MM-dd'T'HH:mm:ssZ"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.date(from: string)

    default: // transformable / binary / objectID — store as-is
        return raw
    }
}
