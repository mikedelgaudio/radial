import CoreGraphics
import Foundation

public struct RingGeometry: Equatable {
    public let slotCount: Int
    public let center: CGPoint
    public let radius: CGFloat

    public init(slotCount: Int, center: CGPoint, radius: CGFloat) {
        self.slotCount = max(1, slotCount)
        self.center = center
        self.radius = radius
    }

    public func angleDegrees(for index: Int) -> CGFloat {
        let step = 360.0 / CGFloat(slotCount)
        return -90 + step * CGFloat(index)
    }

    public func position(for index: Int) -> CGPoint {
        let a = angleDegrees(for: index) * .pi / 180
        return CGPoint(x: center.x + radius * cos(a),
                       y: center.y + radius * sin(a))
    }
}
