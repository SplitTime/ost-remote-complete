import XCTest
@testable import OST_Remote

final class SyncServiceTests: XCTestCase {
    private func entries(_ n: Int) -> [LiveTimeEntry] {
        (0..<n).map { LiveTimeEntry(bibNumber: "\($0)", splitId: "1", subSplitKind: "in",
                                    enteredTime: "t", withPacer: "false", stoppedHere: "false",
                                    source: "ost-remote-ios") }
    }

    func test_batchesIn300sInOrder() async throws {
        var batchSizes: [Int] = []
        let svc = SyncService(login: {}, submitBatch: { batch, _ in batchSizes.append(batch.count) })
        try await svc.sync(entries(650))
        XCTAssertEqual(batchSizes, [300, 300, 50])
    }

    func test_usesPrimaryServerWhenLoginSucceeds() async throws {
        var serversUsed: [Bool] = []
        let svc = SyncService(login: {}, submitBatch: { _, alt in serversUsed.append(alt) })
        try await svc.sync(entries(10))
        XCTAssertEqual(serversUsed, [false])
    }

    func test_usesAlternateServerWhenLoginFails() async throws {
        var serversUsed: [Bool] = []
        let svc = SyncService(login: { throw URLError(.notConnectedToInternet) },
                              submitBatch: { _, alt in serversUsed.append(alt) })
        try await svc.sync(entries(10))
        XCTAssertEqual(serversUsed, [true])
    }

    func test_propagatesSubmitError() async {
        let svc = SyncService(login: {}, submitBatch: { _, _ in throw URLError(.badServerResponse) })
        do {
            try await svc.sync(entries(5))
            XCTFail("expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}
