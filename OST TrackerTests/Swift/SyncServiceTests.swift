import XCTest
@testable import OST_Remote

final class SyncServiceTests: XCTestCase {
    private func entries(_ n: Int) -> [LiveTimeEntry] {
        (0..<n).map { LiveTimeEntry(bibNumber: "\($0)", splitId: "1", subSplitKind: "in",
                                    enteredTime: "t", withPacer: "false", stoppedHere: "false",
                                    source: "ost-remote-ios") }
    }

    private func loginOK(_ done: @escaping (Result<Void, Error>) -> Void) { done(.success(())) }
    private func loginFail(_ done: @escaping (Result<Void, Error>) -> Void) { done(.failure(URLError(.notConnectedToInternet))) }

    func test_batchesIn300sInOrder() {
        var batchSizes: [Int] = []
        let svc = SyncService(login: loginOK) { batch, _, done in batchSizes.append(batch.count); done(.success(())) }
        let exp = expectation(description: "sync")
        svc.sync(entries(650)) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(batchSizes, [300, 300, 50])
    }

    func test_usesPrimaryServerWhenLoginSucceeds() {
        var serversUsed: [Bool] = []
        let svc = SyncService(login: loginOK) { _, alt, done in serversUsed.append(alt); done(.success(())) }
        let exp = expectation(description: "sync")
        svc.sync(entries(10)) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(serversUsed, [false])
    }

    func test_usesAlternateServerWhenLoginFails() {
        var serversUsed: [Bool] = []
        let svc = SyncService(login: loginFail) { _, alt, done in serversUsed.append(alt); done(.success(())) }
        let exp = expectation(description: "sync")
        svc.sync(entries(10)) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(serversUsed, [true])
    }

    func test_propagatesSubmitError() {
        let svc = SyncService(login: loginOK) { _, _, done in done(.failure(URLError(.badServerResponse))) }
        let exp = expectation(description: "sync")
        svc.sync(entries(5)) { result in
            if case .failure(let e) = result { XCTAssertTrue(e is URLError) } else { XCTFail("expected error") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}
