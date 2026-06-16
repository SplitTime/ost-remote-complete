import Foundation

/// Forces the Swift toolchain on for the target during the SwiftUI migration.
/// Will be removed once real Swift code is in place.
@objc final class SwiftSmoke: NSObject {
    @objc static func ping() -> String { "swift-ok" }
}
