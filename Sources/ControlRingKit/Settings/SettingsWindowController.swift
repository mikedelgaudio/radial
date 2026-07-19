import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    private let store: ConfigStore
    private var window: NSWindow?

    public init(store: ConfigStore) { self.store = store }

    public func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func rootView() -> AnyView { AnyView(SettingsView(store: store)) }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Control Ring"
        w.center()
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: rootView())
        return w
    }
}
