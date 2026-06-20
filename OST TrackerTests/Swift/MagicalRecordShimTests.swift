import XCTest
import CoreData
@testable import OST_Remote

/// Verifies the MagicalRecord-compatibility shim against the real `EffortModel`
/// entity on a real on-disk store: JSON:API field mapping, persistence across a
/// store reopen, and `relatedByAttribute` upsert. The Obj-C model classes are
/// resolved at runtime (tests are hosted inside OST Remote.app), so no compile-time
/// import of the Obj-C class is needed.
final class MagicalRecordShimTests: XCTestCase {

    private var storeDir: URL!

    /// `EffortModel`, resolved dynamically from the test host.
    private var effort: NSManagedObject.Type {
        NSClassFromString("EffortModel") as! NSManagedObject.Type
    }

    override func setUpWithError() throws {
        storeDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        CoreDataStack.shared = CoreDataStack(storeURL: storeDir.appendingPathComponent("OSTDataModel"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeDir)
    }

    private func reopenStore() {
        CoreDataStack.shared = CoreDataStack(storeURL: storeDir.appendingPathComponent("OSTDataModel"))
    }

    /// Mirrors the live `efforts` payload shape (matches the fixture data: bib 7 → Camellia Klein).
    private func effortJSON(id: String, bib: Int, name: String) -> [String: Any] {
        return ["id": id, "type": "efforts",
                "attributes": ["age": 29, "bibNumber": bib, "eventId": 437,
                               "fullName": name, "gender": "female",
                               "flexibleGeolocation": "geo"]]
    }

    func test_import_mapsJSONAPIFieldsAndTypes() {
        let object = effort.mr_import(from: effortJSON(id: "59387", bib: 7, name: "Camellia Klein")) as? NSManagedObject
        XCTAssertNotNil(object)
        XCTAssertEqual(object?.value(forKey: "effortId") as? String, "59387")          // id
        XCTAssertEqual(object?.value(forKey: "fullName") as? String, "Camellia Klein")  // attributes.fullName
        XCTAssertEqual(object?.value(forKey: "gender") as? String, "female")
        XCTAssertEqual(object?.value(forKey: "flexibleGeolocation") as? String, "geo")
        XCTAssertEqual(object?.value(forKey: "bibNumber") as? NSDecimalNumber, NSDecimalNumber(value: 7))   // Decimal
        XCTAssertEqual(object?.value(forKey: "eventId") as? NSDecimalNumber, NSDecimalNumber(value: 437))   // Decimal
        XCTAssertEqual((object?.value(forKey: "age") as? NSNumber)?.intValue, 29)        // Integer 16
    }

    func test_data_survivesStoreReopen() {
        _ = effort.mr_import(from: effortJSON(id: "83439", bib: 900, name: "Jon Eisen"))
        NSManagedObjectContext.mr_default().processPendingChanges()
        NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()

        reopenStore() // simulate a fresh app launch on the same on-disk store

        let found = effort.mr_findFirst(with: NSPredicate(format: "effortId == %@", "83439")) as? NSManagedObject
        XCTAssertEqual(found?.value(forKey: "fullName") as? String, "Jon Eisen")
        XCTAssertEqual(found?.value(forKey: "bibNumber") as? NSDecimalNumber, NSDecimalNumber(value: 900))
    }

    func test_import_upsertsByRelatedAttribute_noDuplicates() {
        _ = effort.mr_import(from: effortJSON(id: "100", bib: 5, name: "Before"))
        _ = effort.mr_import(from: effortJSON(id: "100", bib: 5, name: "After"))

        let all = (effort.mr_findAll(with: NSPredicate(format: "effortId == %@", "100")) as? [NSManagedObject]) ?? []
        XCTAssertEqual(all.count, 1, "Re-importing the same id must update in place, not duplicate")
        XCTAssertEqual(all.first?.value(forKey: "fullName") as? String, "After")
    }

    func test_truncateAll_clearsEntity() {
        _ = effort.mr_import(from: effortJSON(id: "1", bib: 1, name: "A"))
        _ = effort.mr_import(from: effortJSON(id: "2", bib: 2, name: "B"))
        effort.mrTruncateAll()
        NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()

        let remaining = (effort.mr_findAll(with: nil) as? [NSManagedObject]) ?? []
        XCTAssertEqual(remaining.count, 0)
    }

    // MARK: - mr_reconcile (prune deleted roster entries)

    /// All effortId values currently in the store.
    private func allEffortIds() -> Set<String> {
        let all = (effort.mr_findAll(with: nil) as? [NSManagedObject]) ?? []
        return Set(all.compactMap { $0.value(forKey: "effortId") as? String })
    }

    func test_reconcile_prunesEffortsMissingFromResponse() {
        effort.mr_reconcile(fromIncluded: [effortJSON(id: "1", bib: 1, name: "Alice"),
                                           effortJSON(id: "2", bib: 2, name: "Bob"),
                                           effortJSON(id: "3", bib: 3, name: "Carol")],
                            ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "2", "3"])

        // Bob (id 2) was removed from the roster on the server.
        effort.mr_reconcile(fromIncluded: [effortJSON(id: "1", bib: 1, name: "Alice"),
                                           effortJSON(id: "3", bib: 3, name: "Carol")],
                            ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "3"], "A runner removed from the server roster must be pruned locally")
    }

    func test_reconcile_emptyEffortsLeavesRosterIntact() {
        effort.mr_reconcile(fromIncluded: [effortJSON(id: "1", bib: 1, name: "Alice"),
                                           effortJSON(id: "2", bib: 2, name: "Bob")],
                            ofType: "efforts")
        // A response carrying no efforts (partial / malformed) must NOT wipe the roster.
        let eventsOnly: [[String: Any]] = [["id": "471", "type": "events",
                                            "attributes": ["shortName": "L100"]]]
        effort.mr_reconcile(fromIncluded: eventsOnly, ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "2"], "Safety guard: no matching members must not prune")
    }

    func test_reconcile_unchangedRosterAddsAndRemovesNothing() {
        let roster = [effortJSON(id: "1", bib: 1, name: "Alice"),
                      effortJSON(id: "2", bib: 2, name: "Bob")]
        effort.mr_reconcile(fromIncluded: roster, ofType: "efforts")
        effort.mr_reconcile(fromIncluded: roster, ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "2"])
    }
}
