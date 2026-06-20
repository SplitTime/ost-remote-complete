// OST TrackerTests/Swift/LiveTimeSubmitterTests.swift
import XCTest
import CoreData
@testable import OST_Remote

final class LiveTimeSubmitterTests: XCTestCase {
    private var ctx: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        ctx = CoreDataStack(inMemory: true).viewContext
    }

    private func makeEntry(bib: String) -> NSManagedObject {
        let e = NSEntityDescription.insertNewObject(forEntityName: "EntryModel", into: ctx)
        e.setValue(bib, forKey: "bibNumber")
        e.setValue("in", forKey: "bitKey")
        e.setValue("2026-06-20 10:00:00 -06:00", forKey: "absoluteTime")
        e.setValue("false", forKey: "withPacer")
        e.setValue("false", forKey: "stoppedHere")
        e.setValue("ost-remote-test", forKey: "source")
        return e
    }

    func test_mapper_copiesFaithfulFields() {
        let live = liveTimeEntry(from: makeEntry(bib: "42"))
        XCTAssertEqual(live.bibNumber, "42")
        XCTAssertEqual(live.subSplitKind, "in")
        XCTAssertEqual(live.enteredTime, "2026-06-20 10:00:00 -06:00")
        XCTAssertEqual(live.withPacer, "false")
        XCTAssertEqual(live.stoppedHere, "false")
        XCTAssertEqual(live.source, "ost-remote-test")
    }

    func test_submit_marksAllOnSuccess() {
        let entries = (0..<5).map { makeEntry(bib: "\($0)") }
        var marked: [NSManagedObject] = []
        let submitter = LiveTimeSubmitter(
            login: { $0(.success(())) },
            postBatch: { _, _, done in done(.success(())) },
            markSubmitted: { marked.append(contentsOf: $0) })
        let exp = expectation(description: "done")
        submitter.submit(entries, progress: { _ in }) { result in
            if case .failure = result { XCTFail("expected success") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(marked.count, 5)
    }

    func test_submit_partialFailure_marksOnlySucceededBatches() {
        // 350 entries → batches [300, 50]. Fail the second batch.
        let entries = (0..<350).map { makeEntry(bib: "\($0)") }
        var marked: [NSManagedObject] = []
        var batchIndex = 0
        let submitter = LiveTimeSubmitter(
            login: { $0(.success(())) },
            postBatch: { _, _, done in
                let i = batchIndex; batchIndex += 1
                done(i == 0 ? .success(()) : .failure(URLError(.badServerResponse)))
            },
            markSubmitted: { marked.append(contentsOf: $0) })
        let exp = expectation(description: "done")
        submitter.submit(entries, progress: { _ in }) { result in
            if case .success = result { XCTFail("expected failure") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(marked.count, 300, "only the first (succeeded) batch is marked")
    }

    func test_submit_completesWhenLoginAndPostAreAsync() {
        let entries = [makeEntry(bib: "1")]
        let submitter = LiveTimeSubmitter(
            login: { done in DispatchQueue.global().async { done(.success(())) } },
            postBatch: { _, _, done in DispatchQueue.global().async { done(.success(())) } },
            markSubmitted: { _ in })
        let exp = expectation(description: "done")
        submitter.submit(entries, progress: { _ in }) { result in
            if case .failure = result { XCTFail("expected success") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
    }

    func test_submit_usesAlternateServerWhenLoginFails() {
        var serversUsed: [Bool] = []
        let submitter = LiveTimeSubmitter(
            login: { $0(.failure(URLError(.notConnectedToInternet))) },
            postBatch: { _, alt, done in serversUsed.append(alt); done(.success(())) },
            markSubmitted: { _ in })
        let exp = expectation(description: "done")
        submitter.submit([makeEntry(bib: "1")], progress: { _ in }) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(serversUsed, [true])
    }
}
