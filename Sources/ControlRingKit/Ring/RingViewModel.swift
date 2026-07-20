import Foundation
import Combine

public enum ActivationIntent: Equatable {
    case runAction(Action)
    case switchMode(Int)
    case addMode
    case openSettings
    case none
}

@MainActor
public final class RingViewModel: ObservableObject {
    public enum Focus: Equatable { case outer, inner, center }

    private let store: ConfigStore
    private var cancellables = Set<AnyCancellable>()

    @Published public var isOpen = false
    @Published public var focus: Focus = .outer
    @Published public var outerIndex = 0
    @Published public var innerIndex = 0
    @Published public var currentModeIndex = 0
    @Published public var transientMessage: String?
    /// Current ring diameter (persisted). Drives `RingMetrics`.
    @Published public var diameter: CGFloat = RingMetrics.defaultDiameter

    public init(store: ConfigStore) {
        self.store = store
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        if let saved = store.config.settings.ringDiameter {
            diameter = RingMetrics.clamp(CGFloat(saved))
        }
        clampModeIndex()
    }

    /// Set the ring diameter, clamped to the allowed range.
    public func setDiameter(_ d: CGFloat) {
        diameter = RingMetrics.clamp(d)
    }

    /// Update focus + selection from a cursor position in the ring's coordinate
    /// space (top-left origin, y-down), where the ring is centered in a square of
    /// side `size`. Radial distance chooses the ring; angle chooses the slot.
    /// Cursor positions beyond the ring are ignored (selection is left unchanged).
    public func applyCursor(_ point: CGPoint, in size: CGSize) {
        let metrics = RingMetrics(diameter: diameter)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = hypot(point.x - center.x, point.y - center.y)
        if r <= metrics.centerBand {
            focus = .center
        } else if r <= metrics.innerOuterBoundary {
            focus = .inner
            innerIndex = RingGeometry(slotCount: innerItemCount, center: center, radius: 1)
                .nearestIndex(to: point)
        } else if r <= metrics.bezelRadius {
            focus = .outer
            outerIndex = RingGeometry(slotCount: Mode.slotCount, center: center, radius: 1)
                .nearestIndex(to: point)
        }
        // else: cursor outside the ring — keep current selection.
    }

    public var config: Config { store.config }
    public var modes: [Mode] { store.config.modes }
    public var currentMode: Mode? {
        guard modes.indices.contains(currentModeIndex) else { return nil }
        return modes[currentModeIndex]
    }
    /// Inner ring = one item per mode, then an "add mode (+)" item, then Settings.
    public var innerItemCount: Int { modes.count + 2 }
    public var addModeInnerIndex: Int { modes.count }
    public var settingsInnerIndex: Int { modes.count + 1 }

    public func moveSelection(by delta: Int) {
        switch focus {
        case .outer: outerIndex = wrap(outerIndex + delta, Mode.slotCount)
        case .inner: innerIndex = wrap(innerIndex + delta, innerItemCount)
        case .center: break
        }
    }

    public func focusInward() {
        switch focus {
        case .outer: focus = .inner
        case .inner: focus = .center
        case .center: break
        }
    }
    public func focusOutward() {
        switch focus {
        case .center: focus = .inner
        case .inner: focus = .outer
        case .outer: break
        }
    }

    public func selectOuter(_ index: Int) {
        guard (0..<Mode.slotCount).contains(index) else { return }
        focus = .outer; outerIndex = index
    }

    public func activate() -> ActivationIntent {
        switch focus {
        case .outer:
            guard let action = currentMode?.slots[safe: outerIndex]?.action else { return .none }
            return .runAction(action)
        case .inner:
            if innerIndex == settingsInnerIndex { return .openSettings }
            if innerIndex == addModeInnerIndex { return .addMode }
            currentModeIndex = innerIndex
            outerIndex = 0
            return .switchMode(innerIndex)
        case .center:
            return .openSettings
        }
    }

    public func reset() {
        clampModeIndex()
        focus = .outer; outerIndex = 0; innerIndex = currentModeIndex
    }

    private func clampModeIndex() {
        if modes.isEmpty { currentModeIndex = 0 }
        else { currentModeIndex = min(max(0, currentModeIndex), modes.count - 1) }
    }

    private func wrap(_ v: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((v % count) + count) % count
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
