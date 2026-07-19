import XCTest
@testable import ControlRingKit

final class RingGeometryTests: XCTestCase {
    func test_slot0_is_at_top() {
        let g = RingGeometry(slotCount: 8, center: CGPoint(x: 100, y: 100), radius: 50)
        let p = g.position(for: 0)
        XCTAssertEqual(p.x, 100, accuracy: 0.0001)
        XCTAssertEqual(p.y, 50, accuracy: 0.0001)   // top => center.y - radius
    }

    func test_indices_go_clockwise() {
        let g = RingGeometry(slotCount: 8, center: CGPoint(x: 0, y: 0), radius: 10)
        let p2 = g.position(for: 2) // quarter turn clockwise => right (x=+radius)
        XCTAssertEqual(p2.x, 10, accuracy: 0.0001)
        XCTAssertEqual(p2.y, 0, accuracy: 0.0001)
    }

    func test_angle_step_is_uniform() {
        let g = RingGeometry(slotCount: 4, center: .zero, radius: 1)
        XCTAssertEqual(g.angleDegrees(for: 0), -90, accuracy: 0.0001)
        XCTAssertEqual(g.angleDegrees(for: 1), 0, accuracy: 0.0001)
    }
}
