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

    public init(store: ConfigStore) {
        self.store = store
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        clampModeIndex()
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
