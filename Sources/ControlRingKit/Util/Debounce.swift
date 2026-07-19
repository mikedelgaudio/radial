import Foundation

@MainActor
public final class Debouncer {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    public init(delay: TimeInterval = 0.4) { self.delay = delay }
    public func call(_ action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
