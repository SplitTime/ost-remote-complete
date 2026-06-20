import XCTest
@testable import OST_Remote

final class BibEntryTests: XCTestCase {

    func test_isRecordable_isFalse_forNil() {
        XCTAssertFalse(BibEntry.isRecordable(nil))
    }

    func test_isRecordable_isFalse_forEmptyString() {
        XCTAssertFalse(BibEntry.isRecordable(""))
    }

    func test_isRecordable_isTrue_forNonEmptyBib() {
        XCTAssertTrue(BibEntry.isRecordable("42"))
    }
}
