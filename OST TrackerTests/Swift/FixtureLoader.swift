import Foundation
import XCTest

/// Loads recorded API responses from the `Verification/fixtures` folder, which is
/// added to the test bundle as a folder reference (preserving the `fixtures/` path).
enum Fixture {
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> Data {
        let bundle = Bundle(for: FixtureLoaderAnchor.self)
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "fixtures")
                ?? bundle.url(forResource: name, withExtension: "json") else {
            XCTFail("fixture \(name).json not found in test bundle", file: file, line: line)
            return Data()
        }
        return (try? Data(contentsOf: url)) ?? Data()
    }
}

/// Anchor class so `Bundle(for:)` resolves the test bundle.
private final class FixtureLoaderAnchor {}
