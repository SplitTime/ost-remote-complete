import XCTest
import CoreData
@testable import OST_Remote

/// Covers the pure hold-aware eligibility filter that keeps the entry currently
/// displayed on the entry screen out of the Auto Sync batch.
final class AutoSyncEligibilityTests: XCTestCase {
    private var ctx: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        ctx = CoreDataStack(inMemory: true).viewContext
    }

    override func tearDown() {
        ctx = nil
        super.tearDown()
    }

    private func makeEntry(_ bib: String) -> NSManagedObject {
        let e = NSEntityDescription.insertNewObject(forEntityName: "EntryModel", into: ctx)
        e.setValue(bib, forKey: "bibNumber")
        return e
    }

    func test_nilHeld_returnsAll() {
        let a = makeEntry("1"); let b = makeEntry("2")
        let result = entriesEligibleForAutoSync([a, b], heldEntryID: nil)
        XCTAssertEqual(result.count, 2)
    }

    func test_heldEntry_isExcluded_othersKept() {
        let held = makeEntry("1"); let other = makeEntry("2")
        try? ctx.obtainPermanentIDs(for: [held, other])
        let result = entriesEligibleForAutoSync([held, other], heldEntryID: held.objectID)
        XCTAssertEqual(result, [other], "held entry is filtered out, the rest remain")
    }

    func test_heldNotInList_returnsAllUnchanged() {
        let a = makeEntry("1"); let b = makeEntry("2"); let stray = makeEntry("3")
        try? ctx.obtainPermanentIDs(for: [a, b, stray])
        let result = entriesEligibleForAutoSync([a, b], heldEntryID: stray.objectID)
        XCTAssertEqual(result, [a, b])
    }
}
