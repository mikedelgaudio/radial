import CoreGraphics

/// Single source of truth for the ring's proportions at a given diameter.
/// Every radius/size is derived from `diameter` so the ring scales uniformly.
/// Ratios are taken from the original 560pt design.
public struct RingMetrics: Equatable {
    public let diameter: CGFloat

    public init(diameter: CGFloat) {
        self.diameter = RingMetrics.clamp(diameter)
    }

    // Design ratios (relative to a 560pt reference diameter).
    private static let base: CGFloat = 560
    public var bezelRadius: CGFloat { diameter * (268 / Self.base) }
    public var outerRadius: CGFloat { diameter * (210 / Self.base) }
    public var innerRadius: CGFloat { diameter * (120 / Self.base) }
    public var centerHubRadius: CGFloat { diameter * (62 / Self.base) }
    public var slotSize: CGFloat { diameter * (58 / Self.base) }
    public var chipSize: CGFloat { diameter * (40 / Self.base) }
    public var innerGlowRadius: CGFloat { innerRadius + diameter * (42 / Self.base) }

    /// Radius (from center) at which the diagonal resize handles sit.
    public var handleRadius: CGFloat { bezelRadius }

    /// Radial band boundaries used to classify a cursor position into a ring.
    /// r <= centerBand => center; <= innerOuterBoundary => inner; else outer.
    public var centerBand: CGFloat { (centerHubRadius + innerRadius) / 2 }
    public var innerOuterBoundary: CGFloat { (innerRadius + outerRadius) / 2 }
    /// Clicks farther than this from center are "outside" the ring (dismiss).
    public var dismissRadius: CGFloat { diameter / 2 }

    // Sizing bounds.
    public static let defaultDiameter: CGFloat = 560
    public static let minDiameter: CGFloat = 360
    public static let maxDiameter: CGFloat = 880
    /// Fixed transparent panel side; large enough to hold the biggest ring so the
    /// panel never needs to resize while the ring is scaled.
    public static let panelSize: CGFloat = 920

    public static func clamp(_ d: CGFloat) -> CGFloat {
        min(max(d, minDiameter), maxDiameter)
    }
}
