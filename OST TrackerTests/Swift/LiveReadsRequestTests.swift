import XCTest
@testable import OST_Remote

final class LiveReadsRequestTests: XCTestCase {

    func test_path_includesGroupStationSortAndPageSize() {
        let path = LiveReadsRequest.path(groupId: "437", splitName: "Aid Station 1")
        XCTAssertTrue(path.hasPrefix("event_groups/437/raw_times?"))
        XCTAssertTrue(path.contains("filter[split_name]=Aid%20Station%201"), path)
        XCTAssertTrue(path.contains("sort=-id"), path)
        XCTAssertTrue(path.contains("page[size]=50"), path)
    }

    func test_path_encodesAmpersandsInStationName() {
        let path = LiveReadsRequest.path(groupId: "5", splitName: "Start & Finish")
        XCTAssertTrue(path.contains("Start%20%26%20Finish"), path)
    }
}
