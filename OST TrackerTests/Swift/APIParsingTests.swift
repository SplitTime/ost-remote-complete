import XCTest
@testable import OST_Remote

final class APIParsingTests: XCTestCase {
    func test_parsesEventGroupsList() throws {
        let list = try JSONDecoder().decode(JSONAPIList.self, from: Fixture.data("event_groups_list"))
        let names = list.data.compactMap { $0.attributes.name }
        XCTAssertTrue(names.contains("Test Lonesome 100"), "got: \(names)")
        XCTAssertTrue(list.data.allSatisfy { $0.type == "eventGroups" })
    }

    func test_parsesEventGroupSplits() throws {
        let doc = try JSONDecoder().decode(JSONAPIDoc.self, from: Fixture.data("event_group_437"))
        XCTAssertEqual(doc.data.id, "437")
        let splits = doc.included.filter { $0.type == "splits" }.compactMap { $0.attributes.baseName }
        XCTAssertTrue(splits.contains("Raspberry 1"), "got: \(splits)")
    }

    func test_parsesAuthResponseShape() throws {
        let auth = try JSONDecoder().decode(AuthResponse.self, from: Fixture.data("auth_response"))
        XCTAssertEqual(auth.token, "<<REDACTED_TOKEN>>")
    }
}
