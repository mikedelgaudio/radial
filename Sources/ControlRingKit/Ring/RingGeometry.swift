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

    /// The slot index whose direction from `center` is closest to `point`
    /// (radius-independent — only the angle matters).
    public func nearestIndex(to point: CGPoint) -> Int {
        let target = atan2(point.y - center.y, point.x - center.x)
        var best = 0
        var bestDelta = CGFloat.greatestFiniteMagnitude
        for i in 0..<slotCount {
            let a = angleDegrees(for: i) * .pi / 180
            var delta = abs(target - a).truncatingRemainder(dividingBy: 2 * .pi)
            if delta > .pi { delta = 2 * .pi - delta }
            if delta < bestDelta { bestDelta = delta; best = i }
        }
        return best
    }
}
