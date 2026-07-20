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

    func test_nearestIndex_by_direction() {
        let g = RingGeometry(slotCount: 8, center: CGPoint(x: 100, y: 100), radius: 50)
        XCTAssertEqual(g.nearestIndex(to: CGPoint(x: 100, y: 10)), 0)   // up
        XCTAssertEqual(g.nearestIndex(to: CGPoint(x: 190, y: 100)), 2)  // right
        XCTAssertEqual(g.nearestIndex(to: CGPoint(x: 100, y: 190)), 4)  // down
        XCTAssertEqual(g.nearestIndex(to: CGPoint(x: 10, y: 100)), 6)   // left
    }

    func test_nearestIndex_snaps_to_closest() {
        let g = RingGeometry(slotCount: 8, center: .zero, radius: 1)
        // Slightly clockwise of straight up should still snap to slot 0.
        XCTAssertEqual(g.nearestIndex(to: CGPoint(x: 5, y: -100)), 0)
    }
}
