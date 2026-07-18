import XCTest
@testable import ControlRingKit

final class CoreSpecsCodableTests: XCTestCase {
    func test_kit_links() {
        XCTAssertEqual(ControlRingKit.schemaVersion, 1)
    }
}
