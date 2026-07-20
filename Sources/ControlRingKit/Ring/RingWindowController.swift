import AppKit
import SwiftUI

@MainActor
public final class RingWindowController: NSObject, NSWindowDelegate {
    private let store: ConfigStore
    public let viewModel: RingViewModel
    private let runner = ActionRunner()

    private var panel: RingPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var moveGrabOffset: CGSize?
    private var previousApp: NSRunningApplication?

    public var onOpenSettings: (() -> Void)?

    public init(store: ConfigStore) {
        self.store = store
        self.viewModel = RingViewModel(store: store)
        super.init()
    }

    public func toggle() { viewModel.isOpen ? hide() : show() }

    public func show() {
        guard panel == nil else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        viewModel.reset()

        let side = RingView.panelSize
        let panel = RingPanel(size: CGSize(width: side, height: side))
        panel.animationBehavior = .none
        let host = NSHostingView(rootView: RingView(
            viewModel: viewModel,
            onActivate: { [weak self] in self?.handleActivation() },
            onMoveDrag: { [weak self] in self?.moveWindowFollowingCursor() },
            onMoveEnd: { [weak self] in self?.endWindowMove() }))
        host.frame = NSRect(origin: .zero, size: panel.frame.size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        positionPanel(panel)
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        installMonitors()
        viewModel.isOpen = true
    }

    public func hide() {
        persistFrameAndSize()
        viewModel.isOpen = false
        viewModel.transientMessage = nil
        removeMonitors()
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
    }

    /// Spec: close when the ring loses key focus (e.g. user switches windows).
    public func windowDidResignKey(_ notification: Notification) {
        if viewModel.isOpen { hide() }
    }

    private func handleActivation() {
        switch viewModel.activate() {
        case .runAction(let action):
            // Plan-level failures are synchronous — keep the ring open to show them.
            if case .failure(let error) = runner.plan(for: action) {
                NSLog("ControlRing: \(error)")
                viewModel.transientMessage = error
                scheduleClearMessage()
                return
            }
            // Success: restore the user's previous app first (so scripts/URLs target the
            // right foreground context), close the ring, then run the action.
            let prev = previousApp
            hide()
            prev?.activate()
            _ = runner.run(action)
        case .switchMode:
            break // ring stays open
        case .addMode:
            store.config.modes.append(
                Mode(name: "New Mode", icon: .glyph("apps-grid"),
                     color: .named("gray"), actions: []))
            viewModel.currentModeIndex = store.config.modes.count - 1
            store.save()
            hide()
            onOpenSettings?()
        case .openSettings:
            hide()
            onOpenSettings?()
        case .none:
            break
        }
    }

    private func scheduleClearMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.viewModel.transientMessage = nil
        }
    }

    // MARK: monitors

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.viewModel.isOpen else { return event }
            return self.handleKey(event) ? nil : event
        }
        // Clicks in other apps (panel is non-activating): close.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
        // Clicks inside our panel but outside the ring: close.
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel else { return event }
            let p = event.locationInWindow // panel coords (origin bottom-left)
            let c = CGPoint(x: panel.frame.width / 2, y: panel.frame.height / 2)
            let dismissRadius = RingMetrics(diameter: self.viewModel.diameter).dismissRadius
            if hypot(p.x - c.x, p.y - c.y) > dismissRadius { self.hide(); return nil }
            return event
        }
    }
    private func removeMonitors() {
        for m in [keyMonitor, clickMonitor, localClickMonitor] {
            if let m { NSEvent.removeMonitor(m) }
        }
        keyMonitor = nil; clickMonitor = nil; localClickMonitor = nil
    }

    // MARK: dragging the ring (follows the real cursor for fluid, feedback-free motion)

    private func moveWindowFollowingCursor() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation // screen coords, stable as the window moves
        if moveGrabOffset == nil {
            moveGrabOffset = CGSize(width: panel.frame.origin.x - mouse.x,
                                    height: panel.frame.origin.y - mouse.y)
        }
        guard let off = moveGrabOffset else { return }
        panel.setFrameOrigin(CGPoint(x: mouse.x + off.width, y: mouse.y + off.height))
    }

    private func endWindowMove() {
        moveGrabOffset = nil
        persistFrameAndSize()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123: viewModel.moveSelection(by: -1); return true   // ←
        case 124: viewModel.moveSelection(by: +1); return true   // →
        case 126: viewModel.focusInward(); return true           // ↑
        case 125: viewModel.focusOutward(); return true          // ↓
        case 36, 76, 49: handleActivation(); return true         // return / enter / space
        case 53: hide(); return true                             // esc
        default:
            if let chars = event.charactersIgnoringModifiers,
               let n = Int(chars), (1...Mode.slotCount).contains(n) {
                viewModel.selectOuter(n - 1); return true
            }
            return false
        }
    }

    /// Place the panel at the saved position (from a prior drag), or centered on the
    /// screen containing the cursor on first use. Off-screen saved positions fall back
    /// to centering.
    private func positionPanel(_ panel: NSPanel) {
        let size = panel.frame.size
        let settings = store.config.settings
        if let x = settings.ringOriginX, let y = settings.ringOriginY {
            let origin = CGPoint(x: x, y: y)
            let frame = NSRect(origin: origin, size: size)
            if NSScreen.screens.contains(where: { $0.frame.intersects(frame) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }
        centerOnActiveScreen(panel)
    }

    private func persistFrameAndSize() {
        guard let panel else { return }
        store.config.settings.ringOriginX = Double(panel.frame.origin.x)
        store.config.settings.ringOriginY = Double(panel.frame.origin.y)
        store.config.settings.ringDiameter = Double(viewModel.diameter)
        store.save()
    }

    private func centerOnActiveScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2,
                                     y: frame.midY - size.height / 2))
    }
}
