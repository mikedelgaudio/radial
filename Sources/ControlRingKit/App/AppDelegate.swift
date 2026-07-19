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
        menu.addItem(withTitle: "Summon Ring  (\(store.config.hotkey.displayString))",
                     action: #selector(summon), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Reveal Config", action: #selector(revealConfig), keyEquivalent: "")
        menu.addItem(withTitle: "Restore Defaults", action: #selector(restoreDefaults), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Control Ring", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
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
