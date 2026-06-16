import XCTest
import CoreData
@testable import OST_Remote

final class CoreDataStackTests: XCTestCase {
    func test_loadsExistingModel_andRoundTripsEntry() throws {
        let stack = CoreDataStack(inMemory: true)
        let ctx = stack.viewContext

        let entry = NSEntityDescription.insertNewObject(forEntityName: "EntryModel", into: ctx)
        entry.setValue("123", forKey: "bibNumber")
        try ctx.save()

        let req = NSFetchRequest<NSManagedObject>(entityName: "EntryModel")
        let found = try ctx.fetch(req)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.value(forKey: "bibNumber") as? String, "123")
    }
}
