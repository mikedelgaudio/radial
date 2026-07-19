import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigStore.applicationSupport()
    let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem?

    // Real controllers (their types are added in Task 13):
    var ringController: RingWindowController?
    var settingsController: SettingsWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        store.load()
        setUpStatusItem()

        ringController = RingWindowController(store: store)
        settingsController = SettingsWindowController(store: store)
        ringController?.onOpenSettings = { [weak self] in self?.settingsController?.show() }

        hotKeyManager.register(store.config.hotkey) { [weak self] in
            self?.ringController?.toggle()
        }
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "circle.grid.cross.fill",
                                     accessibilityDescription: "Control Ring")
        let menu = NSMenu()
        // Items targeting the delegate must have their target set explicitly. The Quit
        // item deliberately keeps a nil target so `terminate:` routes up the responder
        // chain to NSApp (AppDelegate doesn't implement terminate:); forcing self as its
        // target would leave it disabled by autoenablesItems.
        for (title, selector, key) in [
            ("Summon Ring  (\(store.config.hotkey.displayString))", #selector(summon), ""),
            ("Settings…", #selector(openSettings), ","),
            ("Reveal Config", #selector(revealConfig), ""),
            ("Restore Defaults", #selector(restoreDefaults), ""),
        ] {
            let menuItem = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            menuItem.target = self
            menu.addItem(menuItem)
            if title.hasPrefix("Summon") || title == "Restore Defaults" { menu.addItem(.separator()) }
        }
        menu.addItem(withTitle: "Quit Control Ring",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        self.statusItem = item
    }

    @objc private func summon() { ringController?.toggle() }
    @objc private func openSettings() { settingsController?.show() }
    @objc private func revealConfig() { store.revealInFinder() }
    @objc private func restoreDefaults() {
        let alert = NSAlert()
        alert.messageText = "Restore default configuration?"
        alert.informativeText = "This overwrites your current modes and slots."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { store.restoreDefaults() }
    }
}
