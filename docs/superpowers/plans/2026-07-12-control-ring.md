# Control Ring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI radial launcher ("Control Ring") — summoned with ⌘⌥⇧+[ — that launches apps (native icons) and scripts from an outer ring, switches modes on an inner ring, is fully keyboard-navigable, themed to macOS, configured via a JSON-backed settings window, and shipped as a CLI-built `.app` (no Xcode).

**Architecture:** A **library target `ControlRingKit`** holds ALL logic and SwiftUI views; a 2-line **executable target `ControlRing`** boots `NSApplication` as a menu-bar accessory and links the kit. This keeps everything unit-testable (tests import the kit) and DRY. Cross-cutting seams: `ProcessRunning`/app-URL resolver injected into `ActionRunner`; `RingViewModel` returns an `ActivationIntent` instead of launching directly; `RingGeometry` is reused by both rings; `ColorSpec`/`IconSpec`/`Theme`/`Tile` are shared by ring and settings.

**Tech Stack:** Swift 6.2 (tools 5.9), SwiftUI + AppKit + Carbon.HIToolbox, Swift Package Manager, XCTest. macOS 13+ deployment. Built with Command Line Tools only.

---

## File Structure

```
Package.swift                              # SPM manifest: kit lib + exe + tests
scripts/run.sh                             # fast debug loop
scripts/build-app.sh                       # assemble signed ControlRing.app
Sources/ControlRing/main.swift             # exe shim -> ControlRingMain.run()
Sources/ControlRingKit/
  App/ControlRingMain.swift                # NSApplication bootstrap
  App/AppDelegate.swift                    # status item, wiring, window mgmt
  Hotkey/HotKeySpec+Carbon.swift           # HotKeySpec <-> Carbon mapping (testable)
  Hotkey/HotKeyManager.swift               # RegisterEventHotKey wrapper
  Model/CoreSpecs.swift                    # ColorSpec, IconSpec, HotKeySpec, enums
  Model/Action.swift                       # Action, Presentation
  Model/Mode.swift                         # Slot, Mode, Settings, Config
  Model/DefaultConfig.swift                # first-run defaults
  Model/ConfigStore.swift                  # load/save/atomic/reveal (ObservableObject)
  Launcher/LaunchPlan.swift                # LaunchPlan enum (testable)
  Launcher/ActionRunner.swift              # plan(for:) + execute via seams
  Ring/RingGeometry.swift                  # angle/position math (testable)
  Ring/RingViewModel.swift                 # focus/selection/intent (testable)
  Ring/RingPanel.swift                     # NSPanel subclass (canBecomeKey)
  Ring/RingWindowController.swift          # show/hide/center, key + click monitors
  Ring/RingView.swift                      # composes the dial
  Ring/OuterRingView.swift                 # outer slots
  Ring/ModeRingView.swift                  # inner mode ring
  Ring/CenterHubView.swift                 # center hub
  Ring/RingBezelCanvas.swift               # decorative bezel/glow (Canvas)
  Ring/SlotTile.swift                      # shared tile (icon-on-color / app icon)
  Settings/SettingsWindowController.swift  # NSWindow host, activation
  Settings/SettingsView.swift              # 3-pane layout
  Settings/ModesSidebar.swift
  Settings/ModeEditorView.swift
  Settings/SlotListView.swift
  Settings/ActionInspectorView.swift
  Settings/SettingsBottomBar.swift
  Theme/Theme.swift                        # appearance-aware colors + palette
  Util/AppIconResolver.swift               # NSWorkspace app-icon lookup
  Util/IconView.swift                      # renders an IconSpec
  Util/Debounce.swift                      # debounce for live-save
Tests/ControlRingTests/
  CoreSpecsCodableTests.swift
  ConfigCodableTests.swift
  DefaultConfigTests.swift
  ConfigStoreTests.swift
  RingGeometryTests.swift
  RingViewModelTests.swift
  ActionRunnerTests.swift
  HotKeyCarbonTests.swift
```

**Palette (single source of truth in `Theme`):** `amber, red, orange, yellow, green, teal, blue, indigo, purple, pink, brown, gray`. `ColorSpec.named(key)` resolves through this palette; ring accent = active mode color; base surfaces adapt to light/dark.

---

## Task 1: Project scaffolding (SPM kit + exe + test harness)

**Files:**
- Create: `Package.swift`
- Create: `Sources/ControlRing/main.swift`
- Create: `Sources/ControlRingKit/App/ControlRingMain.swift`
- Create: `scripts/run.sh`, `scripts/build-app.sh` (build-app.sh fully written in Task 18)
- Test: `Tests/ControlRingTests/CoreSpecsCodableTests.swift` (starts as a harness smoke test)

- [ ] **Step 1: Write the failing test**

`Tests/ControlRingTests/CoreSpecsCodableTests.swift`:
```swift
import XCTest
@testable import ControlRingKit

final class CoreSpecsCodableTests: XCTestCase {
    func test_kit_links() {
        XCTAssertEqual(ControlRingKit.schemaVersion, 1)
    }
}
```

- [ ] **Step 2: Create the manifest and sources so it compiles**

`Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ControlRing",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ControlRingKit", path: "Sources/ControlRingKit"),
        .executableTarget(
            name: "ControlRing",
            dependencies: ["ControlRingKit"],
            path: "Sources/ControlRing"
        ),
        .testTarget(
            name: "ControlRingTests",
            dependencies: ["ControlRingKit"],
            path: "Tests/ControlRingTests"
        ),
    ]
)
```

`Sources/ControlRingKit/App/ControlRingMain.swift`:
```swift
import AppKit

public enum ControlRingKit {
    public static let schemaVersion = 1
}

public enum ControlRingMain {
    public static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
```

`Sources/ControlRing/main.swift`:
```swift
import ControlRingKit

ControlRingMain.run()
```

> NOTE: `AppDelegate` is created in Task 12. Until then, temporarily stub it at the
> bottom of `ControlRingMain.swift` with `final class AppDelegate: NSObject, NSApplicationDelegate {}`
> and DELETE that stub when Task 12 adds the real file.

`scripts/run.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
exec ./.build/debug/ControlRing
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `chmod +x scripts/*.sh && swift test 2>&1 | tail -20`
Expected: builds, `test_kit_links` PASSES.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: scaffold ControlRing SPM kit, exe shim, and test harness"
```

---

## Task 2: Core spec value types (ColorSpec, IconSpec, HotKeySpec, enums)

**Files:**
- Create: `Sources/ControlRingKit/Model/CoreSpecs.swift`
- Test: `Tests/ControlRingTests/CoreSpecsCodableTests.swift` (extend)

- [ ] **Step 1: Write the failing tests**

Replace `CoreSpecsCodableTests.swift` body with:
```swift
import XCTest
@testable import ControlRingKit

final class CoreSpecsCodableTests: XCTestCase {
    func test_kit_links() {
        XCTAssertEqual(ControlRingKit.schemaVersion, 1)
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let back = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(value, back)
    }

    func test_colorSpec_roundTrips_named_and_rgba() throws {
        try roundTrip(ColorSpec.named("amber"))
        try roundTrip(ColorSpec.rgba(0.1, 0.2, 0.3, 1.0))
    }

    func test_iconSpec_roundTrips_all_cases() throws {
        try roundTrip(IconSpec.appIcon)
        try roundTrip(IconSpec.symbol("safari"))
        try roundTrip(IconSpec.glyph("apps-grid"))
    }

    func test_hotKeySpec_default_is_cmd_opt_shift_leftBracket() {
        let hk = HotKeySpec.default
        XCTAssertEqual(hk.keyCode, 33) // kVK_ANSI_LeftBracket
        XCTAssertEqual(Set(hk.modifiers), ["command", "option", "shift"])
    }

    func test_actionType_and_availability_are_string_codable() throws {
        try roundTrip(ActionType.application)
        try roundTrip(Availability.generalAndContextual)
        let data = try JSONEncoder().encode(ActionType.script)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"script\"")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `ColorSpec` / `IconSpec` / `HotKeySpec` undefined.

- [ ] **Step 3: Implement `CoreSpecs.swift`**

```swift
import Foundation

public enum ActionType: String, Codable, Equatable, CaseIterable, Hashable {
    case application, script, url, folder
}

public enum Availability: String, Codable, Equatable, CaseIterable, Hashable {
    case general, contextual, generalAndContextual
}

public enum IconSpec: Codable, Equatable, Hashable {
    case appIcon
    case symbol(String)   // SF Symbol name
    case glyph(String)    // built-in glyph id

    private enum Kind: String, Codable { case appIcon, symbol, glyph }
    private enum CodingKeys: String, CodingKey { case kind, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .appIcon: self = .appIcon
        case .symbol:  self = .symbol(try c.decode(String.self, forKey: .value))
        case .glyph:   self = .glyph(try c.decode(String.self, forKey: .value))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .appIcon: try c.encode(Kind.appIcon, forKey: .kind)
        case .symbol(let s): try c.encode(Kind.symbol, forKey: .kind); try c.encode(s, forKey: .value)
        case .glyph(let g):  try c.encode(Kind.glyph, forKey: .kind); try c.encode(g, forKey: .value)
        }
    }
}

public enum ColorSpec: Codable, Equatable, Hashable {
    case named(String)                          // palette key (see Theme.palette)
    case rgba(Double, Double, Double, Double)

    private enum Kind: String, Codable { case named, rgba }
    private enum CodingKeys: String, CodingKey { case kind, name, r, g, b, a }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .named:
            self = .named(try c.decode(String.self, forKey: .name))
        case .rgba:
            self = .rgba(try c.decode(Double.self, forKey: .r),
                         try c.decode(Double.self, forKey: .g),
                         try c.decode(Double.self, forKey: .b),
                         try c.decode(Double.self, forKey: .a))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .named(let n):
            try c.encode(Kind.named, forKey: .kind); try c.encode(n, forKey: .name)
        case .rgba(let r, let g, let b, let a):
            try c.encode(Kind.rgba, forKey: .kind)
            try c.encode(r, forKey: .r); try c.encode(g, forKey: .g)
            try c.encode(b, forKey: .b); try c.encode(a, forKey: .a)
        }
    }
}

public struct HotKeySpec: Codable, Equatable, Hashable {
    public var keyCode: Int
    public var modifiers: [String]   // "command","option","shift","control"

    public init(keyCode: Int, modifiers: [String]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    public static let `default` = HotKeySpec(
        keyCode: 33, modifiers: ["command", "option", "shift"]
    )
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: all CoreSpecs tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add core spec value types (Color/Icon/HotKey/enums)"
```

---

## Task 3: Action & Presentation model

**Files:**
- Create: `Sources/ControlRingKit/Model/Action.swift`
- Test: `Tests/ControlRingTests/ConfigCodableTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/ControlRingTests/ConfigCodableTests.swift`:
```swift
import XCTest
@testable import ControlRingKit

final class ConfigCodableTests: XCTestCase {
    func test_action_roundTrips() throws {
        let a = Action(
            title: "Safari", type: .application,
            bundleID: "com.apple.Safari",
            presentation: Presentation(icon: .appIcon, color: .named("blue"))
        )
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(Action.self, from: data)
        XCTAssertEqual(a, back)
    }

    func test_action_defaults_when_optional_fields_missing() throws {
        // Forward/back compat: a minimal JSON must decode with sane defaults.
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111",
         "title":"Bare","type":"url",
         "presentation":{"icon":{"kind":"symbol","value":"globe"},
                         "color":{"kind":"named","name":"amber"}}}
        """.data(using: .utf8)!
        let a = try JSONDecoder().decode(Action.self, from: json)
        XCTAssertEqual(a.title, "Bare")
        XCTAssertEqual(a.arguments, [])
        XCTAssertNil(a.subtitle)
        XCTAssertEqual(a.availability, .general)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `Action` / `Presentation` undefined.

- [ ] **Step 3: Implement `Action.swift`**

```swift
import Foundation

public struct Presentation: Codable, Equatable, Hashable {
    public var icon: IconSpec
    public var color: ColorSpec
    public init(icon: IconSpec, color: ColorSpec) {
        self.icon = icon
        self.color = color
    }
}

public struct Action: Codable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var subtitle: String?
    public var type: ActionType
    public var bundleID: String?
    public var appPath: String?
    public var arguments: [String]
    public var scriptCommand: String?
    public var url: String?
    public var folderPath: String?
    public var presentation: Presentation
    public var availability: Availability

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        type: ActionType,
        bundleID: String? = nil,
        appPath: String? = nil,
        arguments: [String] = [],
        scriptCommand: String? = nil,
        url: String? = nil,
        folderPath: String? = nil,
        presentation: Presentation,
        availability: Availability = .general
    ) {
        self.id = id; self.title = title; self.subtitle = subtitle
        self.type = type; self.bundleID = bundleID; self.appPath = appPath
        self.arguments = arguments; self.scriptCommand = scriptCommand
        self.url = url; self.folderPath = folderPath
        self.presentation = presentation; self.availability = availability
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type, bundleID, appPath, arguments
        case scriptCommand, url, folderPath, presentation, availability
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        type = try c.decode(ActionType.self, forKey: .type)
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID)
        appPath = try c.decodeIfPresent(String.self, forKey: .appPath)
        arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        scriptCommand = try c.decodeIfPresent(String.self, forKey: .scriptCommand)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        folderPath = try c.decodeIfPresent(String.self, forKey: .folderPath)
        presentation = try c.decode(Presentation.self, forKey: .presentation)
        availability = try c.decodeIfPresent(Availability.self, forKey: .availability) ?? .general
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add Action and Presentation model"
```

---

## Task 4: Mode, Slot, Settings, Config model

**Files:**
- Create: `Sources/ControlRingKit/Model/Mode.swift`
- Test: `Tests/ControlRingTests/ConfigCodableTests.swift` (extend)

Slots are a **fixed length of 8** (`Mode.slotCount`). Helpers guarantee this.

- [ ] **Step 1: Add failing tests** (append methods to `ConfigCodableTests`)

```swift
    func test_mode_normalizes_to_eight_slots() {
        let m = Mode(name: "X", icon: .glyph("apps-grid"), color: .named("amber"),
                     actions: [nil, nil])
        XCTAssertEqual(m.slots.count, Mode.slotCount)
        XCTAssertEqual(m.slots.map(\.index), Array(0..<Mode.slotCount))
    }

    func test_config_roundTrips() throws {
        let cfg = Config(
            hotkey: .default,
            modes: [Mode(name: "Apps", icon: .glyph("apps-grid"),
                         color: .named("amber"), actions: [])],
            settings: Settings())
        let data = try JSONEncoder().encode(cfg)
        let back = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(cfg, back)
    }

    func test_mode_defaults_contextual_false_when_missing() throws {
        let json = """
        {"id":"22222222-2222-2222-2222-222222222222","name":"Apps",
         "icon":{"kind":"glyph","value":"apps-grid"},
         "color":{"kind":"named","name":"amber"},"slots":[]}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(Mode.self, from: json)
        XCTAssertFalse(m.contextual)
        XCTAssertEqual(m.slots.count, Mode.slotCount) // normalized on decode
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `Mode`/`Slot`/`Settings`/`Config` undefined.

- [ ] **Step 3: Implement `Mode.swift`**

```swift
import Foundation

public struct Slot: Codable, Equatable, Identifiable, Hashable {
    public var index: Int
    public var action: Action?
    public var id: Int { index }
    public init(index: Int, action: Action? = nil) {
        self.index = index; self.action = action
    }
}

public struct Mode: Codable, Equatable, Identifiable, Hashable {
    public static let slotCount = 8

    public var id: UUID
    public var name: String
    public var icon: IconSpec
    public var color: ColorSpec
    public var contextual: Bool
    public var slots: [Slot]

    /// Designated init that normalizes to exactly `slotCount` slots.
    public init(id: UUID = UUID(), name: String, icon: IconSpec, color: ColorSpec,
                contextual: Bool = false, slots: [Slot]) {
        self.id = id; self.name = name; self.icon = icon
        self.color = color; self.contextual = contextual
        self.slots = Mode.normalized(slots)
    }

    /// Convenience: build from an ordered list of optional actions.
    public init(id: UUID = UUID(), name: String, icon: IconSpec, color: ColorSpec,
                contextual: Bool = false, actions: [Action?]) {
        let slots = actions.enumerated().map { Slot(index: $0.offset, action: $0.element) }
        self.init(id: id, name: name, icon: icon, color: color,
                  contextual: contextual, slots: slots)
    }

    public var filledCount: Int { slots.filter { $0.action != nil }.count }

    public static func normalized(_ input: [Slot]) -> [Slot] {
        (0..<slotCount).map { i in
            Slot(index: i, action: input.first(where: { $0.index == i })?.action)
        }
    }

    private enum CodingKeys: String, CodingKey { case id, name, icon, color, contextual, slots }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(IconSpec.self, forKey: .icon)
        color = try c.decode(ColorSpec.self, forKey: .color)
        contextual = try c.decodeIfPresent(Bool.self, forKey: .contextual) ?? false
        let raw = try c.decodeIfPresent([Slot].self, forKey: .slots) ?? []
        slots = Mode.normalized(raw)
    }
}

public struct Settings: Codable, Equatable, Hashable {
    public var showInMenuBar: Bool
    public init(showInMenuBar: Bool = true) { self.showInMenuBar = showInMenuBar }

    private enum CodingKeys: String, CodingKey { case showInMenuBar }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
    }
}

public struct Config: Codable, Equatable, Hashable {
    public var version: Int
    public var hotkey: HotKeySpec
    public var modes: [Mode]
    public var settings: Settings

    public init(version: Int = ControlRingKit.schemaVersion,
                hotkey: HotKeySpec = .default,
                modes: [Mode], settings: Settings = Settings()) {
        self.version = version; self.hotkey = hotkey
        self.modes = modes; self.settings = settings
    }

    private enum CodingKeys: String, CodingKey { case version, hotkey, modes, settings }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? ControlRingKit.schemaVersion
        hotkey = try c.decodeIfPresent(HotKeySpec.self, forKey: .hotkey) ?? .default
        modes = try c.decodeIfPresent([Mode].self, forKey: .modes) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add Mode/Slot/Settings/Config model with lenient decoding"
```

---

## Task 5: Default configuration (first-run seed)

**Files:**
- Create: `Sources/ControlRingKit/Model/DefaultConfig.swift`
- Test: `Tests/ControlRingTests/DefaultConfigTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/ControlRingTests/DefaultConfigTests.swift`:
```swift
import XCTest
@testable import ControlRingKit

final class DefaultConfigTests: XCTestCase {
    func test_default_has_expected_modes() {
        let cfg = DefaultConfig.make()
        XCTAssertEqual(cfg.modes.map(\.name), ["Apps", "Web", "Dev", "System"])
        XCTAssertEqual(cfg.hotkey, .default)
    }

    func test_apps_mode_seeds_known_apps_in_order() {
        let apps = DefaultConfig.make().modes.first { $0.name == "Apps" }!
        let titles = apps.slots.compactMap { $0.action?.title }
        XCTAssertTrue(titles.contains("Safari"))
        XCTAssertTrue(titles.contains("Terminal"))
        XCTAssertEqual(apps.slots.count, Mode.slotCount)
    }

    func test_default_config_is_codable_roundtrip() throws {
        let cfg = DefaultConfig.make()
        let data = try JSONEncoder().encode(cfg)
        XCTAssertEqual(try JSONDecoder().decode(Config.self, from: data), cfg)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `DefaultConfig` undefined.

- [ ] **Step 3: Implement `DefaultConfig.swift`**

```swift
import Foundation

public enum DefaultConfig {
    public static func make() -> Config {
        Config(hotkey: .default, modes: [appsMode(), webMode(), devMode(), systemMode()])
    }

    private static func app(_ title: String, _ bundleID: String, _ color: String) -> Action {
        Action(title: title, type: .application, bundleID: bundleID,
               presentation: Presentation(icon: .appIcon, color: .named(color)))
    }
    private static func urlAction(_ title: String, _ url: String, _ symbol: String, _ color: String) -> Action {
        Action(title: title, type: .url, url: url,
               presentation: Presentation(icon: .symbol(symbol), color: .named(color)))
    }
    private static func script(_ title: String, _ cmd: String, _ symbol: String, _ color: String) -> Action {
        Action(title: title, type: .script, arguments: [], scriptCommand: cmd,
               presentation: Presentation(icon: .symbol(symbol), color: .named(color)))
    }

    private static func appsMode() -> Mode {
        Mode(name: "Apps", icon: .glyph("apps-grid"), color: .named("amber"), actions: [
            app("Safari", "com.apple.Safari", "blue"),
            app("Notes", "com.apple.Notes", "yellow"),
            nil,
            app("Mail", "com.apple.mail", "pink"),
            app("Music", "com.apple.Music", "red"),
            nil,
            app("Terminal", "com.apple.Terminal", "green"),
            nil,
        ])
    }
    private static func webMode() -> Mode {
        Mode(name: "Web", icon: .symbol("globe"), color: .named("blue"), actions: [
            urlAction("GitHub", "https://github.com", "chevron.left.forwardslash.chevron.right", "gray"),
            urlAction("Gmail", "https://mail.google.com", "envelope.fill", "red"),
            urlAction("Calendar", "https://calendar.google.com", "calendar", "blue"),
            urlAction("YouTube", "https://youtube.com", "play.rectangle.fill", "red"),
            urlAction("Maps", "https://maps.google.com", "map.fill", "green"),
            nil, nil, nil,
        ])
    }
    private static func devMode() -> Mode {
        Mode(name: "Dev", icon: .symbol("chevron.left.forwardslash.chevron.right"),
             color: .named("green"), actions: [
            app("Xcode", "com.apple.dt.Xcode", "blue"),
            app("Terminal", "com.apple.Terminal", "green"),
            script("Localhost", "open http://localhost:3000", "network", "teal"),
            script("Flush DNS", "sudo dscacheutil -flushcache", "arrow.clockwise", "orange"),
            nil, nil, nil, nil,
        ])
    }
    private static func systemMode() -> Mode {
        Mode(name: "System", icon: .symbol("gearshape.fill"), color: .named("gray"), actions: [
            app("System Settings", "com.apple.systempreferences", "gray"),
            script("Sleep", "pmset sleepnow", "moon.fill", "indigo"),
            script("Lock Screen", "pmset displaysleepnow", "lock.fill", "blue"),
            nil, nil, nil, nil, nil,
        ])
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add first-run default configuration"
```

---

## Task 6: ConfigStore (load/save/atomic/corrupt-backup/reveal)

**Files:**
- Create: `Sources/ControlRingKit/Model/ConfigStore.swift`
- Test: `Tests/ControlRingTests/ConfigStoreTests.swift`

`ConfigStore` is `@MainActor final class ... ObservableObject` with `@Published var config`.
It takes an injected **directory URL** so tests use a temp dir (DRY seam; production
passes Application Support).

- [ ] **Step 1: Write failing tests**

`Tests/ControlRingTests/ConfigStoreTests.swift`:
```swift
import XCTest
@testable import ControlRingKit

@MainActor
final class ConfigStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("cr-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func test_first_load_writes_defaults() throws {
        let dir = tempDir()
        let store = ConfigStore(directory: dir)
        store.load()
        XCTAssertEqual(store.config.modes.map(\.name), ["Apps", "Web", "Dev", "System"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func test_save_then_load_roundtrips() throws {
        let dir = tempDir()
        let a = ConfigStore(directory: dir); a.load()
        a.config.modes[0].name = "Renamed"
        a.save()
        let b = ConfigStore(directory: dir); b.load()
        XCTAssertEqual(b.config.modes[0].name, "Renamed")
    }

    func test_corrupt_file_is_backed_up_and_defaults_loaded() throws {
        let dir = tempDir()
        let store = ConfigStore(directory: dir)
        try "not json".data(using: .utf8)!.write(to: store.fileURL)
        store.load()
        XCTAssertEqual(store.config.modes.map(\.name), ["Apps", "Web", "Dev", "System"])
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("config.corrupt-") }
        XCTAssertEqual(backups.count, 1)
    }

    func test_restoreDefaults_overwrites() throws {
        let dir = tempDir()
        let store = ConfigStore(directory: dir); store.load()
        store.config.modes = []
        store.save()
        store.restoreDefaults()
        XCTAssertEqual(store.config.modes.map(\.name), ["Apps", "Web", "Dev", "System"])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `ConfigStore` undefined.

- [ ] **Step 3: Implement `ConfigStore.swift`**

```swift
import Foundation
import Combine

@MainActor
public final class ConfigStore: ObservableObject {
    @Published public var config: Config = Config(modes: [])
    public let directory: URL

    public var fileURL: URL { directory.appendingPathComponent("config.json") }

    /// Production convenience: ~/Library/Application Support/ControlRing
    public static func applicationSupport() -> ConfigStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ConfigStore(directory: base.appendingPathComponent("ControlRing", isDirectory: true))
    }

    public init(directory: URL) { self.directory = directory }

    public func load() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            config = DefaultConfig.make(); writeToDisk(); return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            backupCorruptFile()
            config = DefaultConfig.make()
            writeToDisk()
        }
    }

    public func save() { writeToDisk() }

    public func restoreDefaults() {
        config = DefaultConfig.make()
        writeToDisk()
    }

    public func revealInFinder() {
        NSWorkspaceReveal.reveal(fileURL)
    }

    private func writeToDisk() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("ControlRing: failed to write config: \(error)")
        }
    }

    private func backupCorruptFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = directory.appendingPathComponent("config.corrupt-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: dest)
    }
}
```

> `NSWorkspaceReveal` is a tiny AppKit shim (avoids importing AppKit in the test path):
> `Sources/ControlRingKit/Util/NSWorkspaceReveal.swift`:
```swift
import AppKit
enum NSWorkspaceReveal {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: PASS (all 4 ConfigStore tests).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add ConfigStore with atomic save, corrupt backup, reveal"
```

---

## Task 7: RingGeometry (angle/position math)

**Files:**
- Create: `Sources/ControlRingKit/Ring/RingGeometry.swift`
- Test: `Tests/ControlRingTests/RingGeometryTests.swift`

Slot 0 is at the **top** (12 o'clock) and indices increase **clockwise**.
In view coordinates y grows downward, so top = angle −90° = (cos −90°, sin −90°) = (0, −1).

- [ ] **Step 1: Write failing tests**

`Tests/ControlRingTests/RingGeometryTests.swift`:
```swift
import XCTest
@testable import ControlRingKit

final class RingGeometryTests: XCTestCase {
    func test_slot0_is_at_top() {
        let g = RingGeometry(slotCount: 8, center: CGPoint(x: 100, y: 100), radius: 50)
        let p = g.position(for: 0)
        XCTAssertEqual(p.x, 100, accuracy: 0.0001)
        XCTAssertEqual(p.y, 50, accuracy: 0.0001)   // top => center.y - radius
    }

    func test_indices_go_clockwise() {
        let g = RingGeometry(slotCount: 8, center: CGPoint(x: 0, y: 0), radius: 10)
        let p2 = g.position(for: 2) // quarter turn clockwise => right (x=+radius)
        XCTAssertEqual(p2.x, 10, accuracy: 0.0001)
        XCTAssertEqual(p2.y, 0, accuracy: 0.0001)
    }

    func test_angle_step_is_uniform() {
        let g = RingGeometry(slotCount: 4, center: .zero, radius: 1)
        XCTAssertEqual(g.angleDegrees(for: 0), -90, accuracy: 0.0001)
        XCTAssertEqual(g.angleDegrees(for: 1), 0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `RingGeometry` undefined.

- [ ] **Step 3: Implement `RingGeometry.swift`**

```swift
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add RingGeometry slot placement math"
```

---

## Task 8: RingViewModel (focus, selection, activation intent)

**Files:**
- Create: `Sources/ControlRingKit/Ring/RingViewModel.swift`
- Test: `Tests/ControlRingTests/RingViewModelTests.swift`

The view model owns pure navigation state and returns an **`ActivationIntent`**;
it never launches anything itself (decoupled for testing + DRY). The window
controller maps intents to `ActionRunner` / mode switch / open settings.

Inner-ring items = the modes, followed by a trailing **Settings** item. Focus
order is `[outer, inner, center]`; ↑ moves inward (toward center), ↓ moves outward.

- [ ] **Step 1: Write failing tests**

`Tests/ControlRingTests/RingViewModelTests.swift`:
```swift
import XCTest
@testable import ControlRingKit

@MainActor
final class RingViewModelTests: XCTestCase {
    private func vm() -> RingViewModel {
        let store = ConfigStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-\(UUID().uuidString)"))
        store.config = DefaultConfig.make()
        return RingViewModel(store: store)
    }

    func test_left_wraps_outer_selection() {
        let m = vm()
        m.focus = .outer; m.outerIndex = 0
        m.moveSelection(by: -1)
        XCTAssertEqual(m.outerIndex, Mode.slotCount - 1)
    }

    func test_right_advances_and_wraps() {
        let m = vm()
        m.focus = .outer; m.outerIndex = Mode.slotCount - 1
        m.moveSelection(by: +1)
        XCTAssertEqual(m.outerIndex, 0)
    }

    func test_focus_moves_outer_inner_center_and_back() {
        let m = vm()
        m.focus = .outer
        m.focusInward(); XCTAssertEqual(m.focus, .inner)
        m.focusInward(); XCTAssertEqual(m.focus, .center)
        m.focusInward(); XCTAssertEqual(m.focus, .center) // clamped
        m.focusOutward(); XCTAssertEqual(m.focus, .inner)
        m.focusOutward(); XCTAssertEqual(m.focus, .outer)
        m.focusOutward(); XCTAssertEqual(m.focus, .outer) // clamped
    }

    func test_activate_filled_outer_slot_returns_runAction() {
        let m = vm()
        m.focus = .outer
        // Apps mode slot 0 is Safari in defaults.
        m.outerIndex = 0
        guard case .runAction(let a) = m.activate() else { return XCTFail() }
        XCTAssertEqual(a.title, "Safari")
    }

    func test_activate_empty_outer_slot_returns_none() {
        let m = vm()
        m.focus = .outer; m.outerIndex = 2 // empty in defaults
        XCTAssertEqual(m.activate(), .none)
    }

    func test_activate_inner_mode_switches_mode() {
        let m = vm()
        m.focus = .inner; m.innerIndex = 1 // "Web"
        XCTAssertEqual(m.activate(), .switchMode(1))
        XCTAssertEqual(m.currentModeIndex, 1)
    }

    func test_activate_inner_settings_item_returns_openSettings() {
        let m = vm()
        m.focus = .inner
        m.innerIndex = m.innerItemCount - 1 // trailing Settings item
        XCTAssertEqual(m.activate(), .openSettings)
    }

    func test_activate_center_opens_settings() {
        let m = vm()
        m.focus = .center
        XCTAssertEqual(m.activate(), .openSettings)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `RingViewModel` undefined.

- [ ] **Step 3: Implement `RingViewModel.swift`**

```swift
import Foundation
import Combine

public enum ActivationIntent: Equatable {
    case runAction(Action)
    case switchMode(Int)
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
    /// Inner ring = one item per mode + a trailing Settings item.
    public var innerItemCount: Int { modes.count + 1 }
    public var settingsInnerIndex: Int { modes.count }

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
            currentModeIndex = innerIndex
            outerIndex = 0
            return .switchMode(innerIndex)
        case .center:
            return .openSettings
        }
    }

    public func reset() {
        focus = .outer; outerIndex = 0; innerIndex = currentModeIndex
        clampModeIndex()
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: all RingViewModel tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add RingViewModel navigation + activation intent"
```

---

## Task 9: LaunchPlan + ActionRunner (launch seams)

**Files:**
- Create: `Sources/ControlRingKit/Launcher/LaunchPlan.swift`
- Create: `Sources/ControlRingKit/Launcher/ActionRunner.swift`
- Test: `Tests/ControlRingTests/ActionRunnerTests.swift`

`ActionRunner.plan(for:)` builds a **pure, testable** `LaunchPlan`. Execution is a
thin dispatch over injected seams: `resolveAppURL` (bundle id → app URL),
`ProcessRunning` (script), and AppKit `NSWorkspace` (url/folder/app).

- [ ] **Step 1: Write failing tests**

`Tests/ControlRingTests/ActionRunnerTests.swift`:
```swift
import XCTest
@testable import ControlRingKit

final class ActionRunnerTests: XCTestCase {
    private func runner(appURL: URL? = URL(fileURLWithPath: "/Applications/Safari.app"))
        -> ActionRunner {
        ActionRunner(resolveAppURL: { _ in appURL })
    }
    private func pres() -> Presentation { Presentation(icon: .appIcon, color: .named("blue")) }

    func test_application_plan_uses_resolved_url_and_arguments() {
        let a = Action(title: "Safari", type: .application, bundleID: "com.apple.Safari",
                       arguments: ["--flag"], presentation: pres())
        XCTAssertEqual(runner().plan(for: a),
            .application(appURL: URL(fileURLWithPath: "/Applications/Safari.app"),
                         arguments: ["--flag"]))
    }

    func test_application_plan_fails_when_unresolved() {
        let a = Action(title: "Ghost", type: .application, bundleID: "no.such.app",
                       presentation: pres())
        if case .failure = runner(appURL: nil).plan(for: a) {} else { XCTFail() }
    }

    func test_script_plan_wraps_in_sh_lc() {
        let a = Action(title: "Sleep", type: .script, scriptCommand: "pmset sleepnow",
                       presentation: pres())
        XCTAssertEqual(runner().plan(for: a),
            .script(executable: "/bin/sh", arguments: ["-lc", "pmset sleepnow"]))
    }

    func test_script_plan_fails_on_empty_command() {
        let a = Action(title: "X", type: .script, scriptCommand: "  ", presentation: pres())
        if case .failure = runner().plan(for: a) {} else { XCTFail() }
    }

    func test_url_plan() {
        let a = Action(title: "GH", type: .url, url: "https://github.com", presentation: pres())
        XCTAssertEqual(runner().plan(for: a), .openURL(URL(string: "https://github.com")!))
    }

    func test_folder_plan() {
        let a = Action(title: "Home", type: .folder, folderPath: "/Users/me", presentation: pres())
        XCTAssertEqual(runner().plan(for: a), .openFolder(URL(fileURLWithPath: "/Users/me")))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `LaunchPlan` / `ActionRunner` undefined.

- [ ] **Step 3: Implement `LaunchPlan.swift`**

```swift
import Foundation

public enum LaunchPlan: Equatable {
    case application(appURL: URL, arguments: [String])
    case script(executable: String, arguments: [String])
    case openURL(URL)
    case openFolder(URL)
    case failure(String)
}

public protocol ProcessRunning {
    func run(executable: String, arguments: [String]) throws
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}
    public func run(executable: String, arguments: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        try p.run()   // detached; do not wait
    }
}
```

- [ ] **Step 4: Implement `ActionRunner.swift`**

```swift
import Foundation
import AppKit

public struct ActionRunner {
    public var resolveAppURL: (Action) -> URL?
    public var processRunner: ProcessRunning

    public init(resolveAppURL: @escaping (Action) -> URL? = ActionRunner.defaultAppResolver,
                processRunner: ProcessRunning = SystemProcessRunner()) {
        self.resolveAppURL = resolveAppURL
        self.processRunner = processRunner
    }

    public static let defaultAppResolver: (Action) -> URL? = { action in
        if let bundleID = action.bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        if let path = action.appPath, !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    public func plan(for action: Action) -> LaunchPlan {
        switch action.type {
        case .application:
            guard let url = resolveAppURL(action) else {
                return .failure("Could not resolve application \(action.bundleID ?? action.appPath ?? action.title)")
            }
            return .application(appURL: url, arguments: action.arguments)
        case .script:
            let cmd = (action.scriptCommand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cmd.isEmpty else { return .failure("Empty script command") }
            return .script(executable: "/bin/sh", arguments: ["-lc", cmd])
        case .url:
            guard let raw = action.url, let url = URL(string: raw) else {
                return .failure("Invalid URL")
            }
            return .openURL(url)
        case .folder:
            guard let path = action.folderPath, !path.isEmpty else {
                return .failure("Empty folder path")
            }
            return .openFolder(URL(fileURLWithPath: path))
        }
    }

    /// Executes the plan. Returns nil on success or an error message.
    @discardableResult
    @MainActor
    public func run(_ action: Action) -> String? {
        switch plan(for: action) {
        case .application(let url, let args):
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.arguments = args
            NSWorkspace.shared.openApplication(at: url, configuration: cfg)
            return nil
        case .script(let exe, let args):
            do { try processRunner.run(executable: exe, arguments: args); return nil }
            catch { return "Script failed: \(error.localizedDescription)" }
        case .openURL(let url):
            NSWorkspace.shared.open(url); return nil
        case .openFolder(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url]); return nil
        case .failure(let msg):
            return msg
        }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: all ActionRunner tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add ActionRunner with testable LaunchPlan and seams"
```

---

## Task 10: Hotkey — Carbon mapping + manager

**Files:**
- Create: `Sources/ControlRingKit/Hotkey/HotKeySpec+Carbon.swift`
- Create: `Sources/ControlRingKit/Hotkey/HotKeyManager.swift`
- Test: `Tests/ControlRingTests/HotKeyCarbonTests.swift`

The **mapping** is unit-tested; `RegisterEventHotKey` wiring is verified manually
in Task 18's smoke checklist.

- [ ] **Step 1: Write failing tests**

`Tests/ControlRingTests/HotKeyCarbonTests.swift`:
```swift
import XCTest
import Carbon.HIToolbox
@testable import ControlRingKit

final class HotKeyCarbonTests: XCTestCase {
    func test_modifier_mapping_combines_flags() {
        let flags = HotKeySpec(keyCode: 33, modifiers: ["command", "option", "shift"])
            .carbonModifierFlags
        XCTAssertEqual(flags,
            UInt32(cmdKey) | UInt32(optionKey) | UInt32(shiftKey))
    }

    func test_control_flag_maps() {
        XCTAssertEqual(
            HotKeySpec(keyCode: 1, modifiers: ["control"]).carbonModifierFlags,
            UInt32(controlKey))
    }

    func test_unknown_modifier_ignored() {
        XCTAssertEqual(HotKeySpec(keyCode: 1, modifiers: ["hyper"]).carbonModifierFlags, 0)
    }

    func test_display_string() {
        XCTAssertEqual(
            HotKeySpec(keyCode: 33, modifiers: ["command", "option", "shift"]).displayString,
            "⌘⌥⇧[")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `carbonModifierFlags` undefined.

- [ ] **Step 3: Implement `HotKeySpec+Carbon.swift`**

```swift
import Carbon.HIToolbox

public extension HotKeySpec {
    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        for m in modifiers {
            switch m {
            case "command": flags |= UInt32(cmdKey)
            case "option":  flags |= UInt32(optionKey)
            case "shift":   flags |= UInt32(shiftKey)
            case "control": flags |= UInt32(controlKey)
            default: break
            }
        }
        return flags
    }

    var displayString: String {
        // Order matches the app's convention/screenshot: ⌘⌥⇧⌃ then key.
        var s = ""
        if modifiers.contains("command") { s += "⌘" }
        if modifiers.contains("option")  { s += "⌥" }
        if modifiers.contains("shift")   { s += "⇧" }
        if modifiers.contains("control") { s += "⌃" }
        s += HotKeySpec.keyLabel(for: keyCode)
        return s
    }

    static func keyLabel(for keyCode: Int) -> String {
        switch keyCode {
        case 33: return "["
        case 30: return "]"
        case 49: return "Space"
        default: return "#\(keyCode)"
        }
    }
}
```

- [ ] **Step 4: Implement `HotKeyManager.swift`**

```swift
import Carbon.HIToolbox
import AppKit

public final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onFire: (() -> Void)?
    private let signature: FourCharCode = 0x43526e67 // 'CRng'

    public init() {}

    public func register(_ spec: HotKeySpec, onFire: @escaping () -> Void) {
        unregister()
        self.onFire = onFire

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async { manager.onFire?() }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(UInt32(spec.keyCode), spec.carbonModifierFlags,
                            hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    public func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

    deinit { unregister() }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `swift test 2>&1 | tail -20`
Expected: mapping tests PASS. (Manager compiles; runtime firing verified in Task 18.)

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add Carbon hotkey mapping and RegisterEventHotKey manager"
```

---

## Task 11: Theme, IconView, AppIconResolver, Debouncer (shared UI utilities)

> UI tasks 11–17 are not unit-tested (SwiftUI views); each ends with a **build
> verification** (`swift build 2>&1 | tail -20` → "Build complete!") and, where
> noted, a manual smoke check. Keep views DRY: everything shares `Theme`,
> `IconView`, and `SlotTile`.

**Files:**
- Create: `Sources/ControlRingKit/Theme/Theme.swift`
- Create: `Sources/ControlRingKit/Util/IconView.swift`
- Create: `Sources/ControlRingKit/Util/AppIconResolver.swift`
- Create: `Sources/ControlRingKit/Util/Debounce.swift`

- [ ] **Step 1: Implement `Theme.swift`** (single source of truth for palette + surfaces)

```swift
import SwiftUI

public enum Theme {
    /// Canonical palette. `ColorSpec.named(key)` resolves here; unknown => amber.
    public static let palette: [String: Color] = [
        "amber":  Color(red: 1.00, green: 0.72, blue: 0.20),
        "red":    Color(red: 0.98, green: 0.28, blue: 0.29),
        "orange": Color(red: 1.00, green: 0.58, blue: 0.20),
        "yellow": Color(red: 1.00, green: 0.82, blue: 0.28),
        "green":  Color(red: 0.30, green: 0.78, blue: 0.42),
        "teal":   Color(red: 0.25, green: 0.78, blue: 0.78),
        "blue":   Color(red: 0.25, green: 0.55, blue: 0.98),
        "indigo": Color(red: 0.42, green: 0.42, blue: 0.90),
        "purple": Color(red: 0.66, green: 0.40, blue: 0.92),
        "pink":   Color(red: 0.96, green: 0.38, blue: 0.62),
        "brown":  Color(red: 0.66, green: 0.51, blue: 0.38),
        "gray":   Color(red: 0.60, green: 0.62, blue: 0.66),
    ]
    public static let paletteOrder = ["amber","red","orange","yellow","green","teal",
                                      "blue","indigo","purple","pink","brown","gray"]

    public static func color(_ spec: ColorSpec) -> Color {
        switch spec {
        case .named(let n): return palette[n] ?? palette["amber"]!
        case .rgba(let r, let g, let b, let a):
            return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        }
    }

    /// Base amber accent. The ring tints selection/glow by the ACTIVE MODE's color;
    /// resolve that with `accent(for:)` (falls back to amber).
    public static let accent = palette["amber"]!
    public static func accent(for mode: Mode?) -> Color {
        guard let mode else { return accent }
        return color(mode.color)
    }

    /// Appearance-aware ring plate: dark glass in dark mode, light glass in light mode.
    public static func ringPlate(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.55) : Color.white.opacity(0.62)
    }
    /// Neutral surfaces that read acceptably in both appearances.
    public static let slotPlate = Color.gray.opacity(0.16)
    public static let hairline = Color.gray.opacity(0.28)
}
```

- [ ] **Step 2: Implement `IconView.swift`** (renders an `IconSpec`; glyph→SF Symbol map)

```swift
import SwiftUI

public enum Glyph {
    /// Built-in glyph ids map to SF Symbols so the whole app stays vector.
    public static func symbolName(_ id: String) -> String {
        switch id {
        case "apps-grid": return "square.grid.2x2.fill"
        case "code":      return "chevron.left.forwardslash.chevron.right"
        case "folder":    return "folder.fill"
        case "gear":      return "gearshape.fill"
        case "globe":     return "globe"
        default:          return "app.dashed"
        }
    }
}

public struct IconView: View {
    public let spec: IconSpec
    public var appImage: NSImage?   // supplied for .appIcon (resolved by caller)
    public init(spec: IconSpec, appImage: NSImage? = nil) {
        self.spec = spec; self.appImage = appImage
    }
    public var body: some View {
        switch spec {
        case .appIcon:
            if let appImage {
                Image(nsImage: appImage).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed").resizable().aspectRatio(contentMode: .fit)
            }
        case .symbol(let name):
            Image(systemName: name).resizable().aspectRatio(contentMode: .fit)
        case .glyph(let id):
            Image(systemName: Glyph.symbolName(id)).resizable().aspectRatio(contentMode: .fit)
        }
    }
}
```

- [ ] **Step 3: Implement `AppIconResolver.swift`** (native app icons, cached)

```swift
import AppKit

public enum AppIconResolver {
    private static var cache: [String: NSImage] = [:]

    public static func appImage(for action: Action) -> NSImage? {
        guard action.type == .application else { return nil }
        let key = action.bundleID ?? action.appPath ?? action.title
        if let hit = cache[key] { return hit }
        var url: URL?
        if let bundleID = action.bundleID {
            url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        }
        if url == nil, let path = action.appPath, !path.isEmpty {
            url = URL(fileURLWithPath: path)
        }
        guard let url else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[key] = image
        return image
    }
}
```

- [ ] **Step 4: Implement `Debounce.swift`** (coalesce live-saves)

```swift
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
```

- [ ] **Step 5: Build verification**

Run: `swift build 2>&1 | tail -20`
Expected: "Build complete!"

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add Theme, IconView, AppIconResolver, Debouncer"
```

---

## Task 12: App bootstrap — AppDelegate + status item + wiring

**Files:**
- Create: `Sources/ControlRingKit/App/AppDelegate.swift`
- Modify: `Sources/ControlRingKit/App/ControlRingMain.swift` (remove the temporary AppDelegate stub added in Task 1)

`AppDelegate` owns the singletons and wires them together. It references
`RingWindowController` and `SettingsWindowController`, which are **created in
Task 13**. Therefore the tree intentionally does **not** build at the end of this
task — it goes green at the end of Task 13 (which adds those types and the commit).
This is the only intentional cross-task build gap; every other task ends green.

- [ ] **Step 1: Remove the stub**

Delete the temporary `final class AppDelegate ...` line from `ControlRingMain.swift`.

- [ ] **Step 2: Implement `AppDelegate.swift`**

```swift
import AppKit

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
```

- [ ] **Step 3: Build verification (expected to fail until Task 13)**

Run: `swift build 2>&1 | tail -20`
Expected: FAILS with "cannot find 'RingWindowController'/'SettingsWindowController'".
This is the one intentional cross-task gap. Do NOT commit yet — the commit happens
at the end of Task 13 once those types exist and the build is green.

---

## Task 13: Ring window — panel, controller, keyboard + click monitors

**Files:**
- Create: `Sources/ControlRingKit/Ring/RingPanel.swift`
- Create: `Sources/ControlRingKit/Ring/RingWindowController.swift`
- Create: `Sources/ControlRingKit/Ring/RingView.swift` (placeholder; full composition in Task 14)
- Create: `Sources/ControlRingKit/Settings/SettingsWindowController.swift` (placeholder content; full UI in Task 15)
- Modify: `Sources/ControlRingKit/App/AppDelegate.swift` (wire ring → settings opener)

- [ ] **Step 1: Implement `RingPanel.swift`**

```swift
import AppKit

final class RingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(size: CGSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
    }
}
```

- [ ] **Step 2: Implement `RingView.swift` (placeholder)**

```swift
import SwiftUI

public struct RingView: View {
    @ObservedObject var viewModel: RingViewModel
    let onActivate: () -> Void

    public init(viewModel: RingViewModel, onActivate: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onActivate = onActivate
    }

    public var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.55)).background(.ultraThinMaterial, in: Circle())
            Text("Control Ring").foregroundStyle(.white).font(.headline)
        }
        .frame(width: RingView.diameter, height: RingView.diameter)
        .scaleEffect(viewModel.isOpen ? 1 : 0.85)
        .opacity(viewModel.isOpen ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: viewModel.isOpen)
    }

    static let diameter: CGFloat = 520
}
```

- [ ] **Step 3: Implement `SettingsWindowController.swift` (placeholder content)**

```swift
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

    // Replaced in Task 15 with SettingsView(store:).
    func rootView() -> AnyView {
        AnyView(Text("Settings — coming soon")
            .frame(minWidth: 900, minHeight: 600))
    }

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
```

- [ ] **Step 4: Implement `RingWindowController.swift`**

```swift
import AppKit
import SwiftUI

@MainActor
public final class RingWindowController {
    private let store: ConfigStore
    public let viewModel: RingViewModel
    private let runner = ActionRunner()

    private var panel: RingPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var previousApp: NSRunningApplication?

    public var onOpenSettings: (() -> Void)?

    public init(store: ConfigStore) {
        self.store = store
        self.viewModel = RingViewModel(store: store)
    }

    public func toggle() { viewModel.isOpen ? hide() : show() }

    public func show() {
        guard panel == nil else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        viewModel.reset()

        let panel = RingPanel(size: CGSize(width: RingView.diameter, height: RingView.diameter))
        let host = NSHostingView(rootView: RingView(viewModel: viewModel) { [weak self] in
            self?.handleActivation()
        })
        host.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = host
        centerOnActiveScreen(panel)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        installMonitors()
        viewModel.isOpen = true
    }

    public func hide() {
        viewModel.isOpen = false
        removeMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    private func handleActivation() {
        switch viewModel.activate() {
        case .runAction(let action):
            let prev = previousApp
            hide()
            prev?.activate()
            _ = runner.run(action)
        case .switchMode:
            break // ring stays open
        case .openSettings:
            hide()
            onOpenSettings?()
        case .none:
            break
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
        // Clicks inside our panel but outside the ring circle (transparent corners): close.
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel else { return event }
            let p = event.locationInWindow // panel/content coords (origin bottom-left)
            let c = CGPoint(x: panel.frame.width / 2, y: panel.frame.height / 2)
            let ringRadius = min(panel.frame.width, panel.frame.height) / 2
            if hypot(p.x - c.x, p.y - c.y) > ringRadius { self.hide(); return nil }
            return event
        }
    }
    private func removeMonitors() {
        for m in [keyMonitor, clickMonitor, localClickMonitor] {
            if let m { NSEvent.removeMonitor(m) }
        }
        keyMonitor = nil; clickMonitor = nil; localClickMonitor = nil
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

    private func centerOnActiveScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2,
                                     y: frame.midY - size.height / 2))
    }
}
```

- [ ] **Step 5: Wire ring → settings in `AppDelegate.swift`**

After the `ringController = ...` / `settingsController = ...` lines in
`applicationDidFinishLaunching`, add:
```swift
        ringController?.onOpenSettings = { [weak self] in self?.settingsController?.show() }
```

- [ ] **Step 6: Build verification**

Run: `swift build 2>&1 | tail -20`
Expected: "Build complete!"

- [ ] **Step 7: Manual smoke (first runnable milestone)**

Run: `./scripts/run.sh` (leave running), then press **⌘⌥⇧+[**.
Expected: a dark placeholder ring appears centered; **Esc** closes it; the
menu-bar icon's **Settings…** opens the placeholder window. Ctrl-C to stop.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: add ring panel, window controller, keyboard/click nav; first runnable ring"
```

---

## Task 14: Ring UI composition (tiles, rings, hub, bezel)

**Files:**
- Create: `Sources/ControlRingKit/Ring/SlotTile.swift`
- Create: `Sources/ControlRingKit/Ring/OuterRingView.swift`
- Create: `Sources/ControlRingKit/Ring/ModeRingView.swift`
- Create: `Sources/ControlRingKit/Ring/CenterHubView.swift`
- Create: `Sources/ControlRingKit/Ring/RingBezelCanvas.swift`
- Modify: `Sources/ControlRingKit/Ring/RingView.swift` (replace placeholder body)

Shared geometry constants live on `RingView` so every layer agrees (DRY).

- [ ] **Step 1: Implement `SlotTile.swift`**

```swift
import SwiftUI

public struct SlotTile: View {
    let action: Action?
    let selected: Bool
    var size: CGFloat = 58
    var accent: Color = Theme.accent

    public init(action: Action?, selected: Bool, size: CGFloat = 58, accent: Color = Theme.accent) {
        self.action = action; self.selected = selected; self.size = size; self.accent = accent
    }

    public var body: some View {
        ZStack {
            if let action { filled(action) } else { empty }
        }
        .frame(width: size, height: size)
        .scaleEffect(selected ? 1.15 : 1.0)
        .shadow(color: selected ? accent.opacity(0.55) : .clear,
                radius: selected ? 14 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.29)
                .stroke(accent, lineWidth: selected ? 2.5 : 0)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
    }

    @ViewBuilder private func filled(_ action: Action) -> some View {
        if case .appIcon = action.presentation.icon,
           let image = AppIconResolver.appImage(for: action) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            RoundedRectangle(cornerRadius: size * 0.29)
                .fill(Theme.color(action.presentation.color).gradient)
            IconView(spec: action.presentation.icon)
                .foregroundStyle(.white)
                .padding(size * 0.24)
        }
    }

    private var empty: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(.secondary.opacity(0.55))
            Image(systemName: "plus").foregroundStyle(.secondary)
                .font(.system(size: size * 0.34, weight: .semibold))
        }
    }
}
```

- [ ] **Step 2: Implement `OuterRingView.swift`**

```swift
import SwiftUI

struct OuterRingView: View {
    @ObservedObject var viewModel: RingViewModel
    let center: CGPoint
    let radius: CGFloat
    let accent: Color
    let onActivate: () -> Void

    var body: some View {
        let geo = RingGeometry(slotCount: Mode.slotCount, center: center, radius: radius)
        ForEach(0..<Mode.slotCount, id: \.self) { i in
            SlotTile(action: viewModel.currentMode?.slots[safe: i]?.action,
                     selected: viewModel.focus == .outer && viewModel.outerIndex == i,
                     accent: accent)
                .position(geo.position(for: i))
                .onHover { if $0 { viewModel.selectOuter(i) } }
                .onTapGesture { viewModel.selectOuter(i); onActivate() }
        }
    }
}
```

- [ ] **Step 3: Implement `ModeRingView.swift`**

```swift
import SwiftUI

struct ModeRingView: View {
    @ObservedObject var viewModel: RingViewModel
    let center: CGPoint
    let radius: CGFloat
    let accent: Color
    let onActivate: () -> Void

    var body: some View {
        let count = viewModel.innerItemCount
        let geo = RingGeometry(slotCount: count, center: center, radius: radius)
        ForEach(0..<count, id: \.self) { i in
            chip(for: i)
                .position(geo.position(for: i))
                .onHover { if $0 { viewModel.focus = .inner; viewModel.innerIndex = i } }
                .onTapGesture {
                    viewModel.focus = .inner; viewModel.innerIndex = i; onActivate()
                }
        }
    }

    @ViewBuilder private func chip(for i: Int) -> some View {
        let isSettings = i == viewModel.settingsInnerIndex
        let selected = viewModel.focus == .inner && viewModel.innerIndex == i
        let current = !isSettings && viewModel.currentModeIndex == i
        let icon: IconSpec = isSettings ? .glyph("gear") : viewModel.modes[i].icon
        let tint: Color = isSettings ? Theme.color(.named("gray"))
                                     : Theme.color(viewModel.modes[i].color)
        ZStack {
            Circle().fill(current ? tint.opacity(0.28) : Color.gray.opacity(0.12))
            IconView(spec: icon)
                .foregroundStyle(current ? tint : .primary.opacity(0.8))
                .padding(10)
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().stroke(accent, lineWidth: selected ? 2 : 0))
        .scaleEffect(selected ? 1.18 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
    }
}
```

- [ ] **Step 4: Implement `CenterHubView.swift`**

```swift
import SwiftUI

struct CenterHubView: View {
    @ObservedObject var viewModel: RingViewModel
    let radius: CGFloat
    let accent: Color
    let onActivate: () -> Void

    var body: some View {
        let selected = viewModel.focus == .center
        let mode = viewModel.currentMode
        ZStack {
            Circle().fill(
                RadialGradient(colors: [accent.opacity(0.35), .clear],
                               center: .center, startRadius: 2, endRadius: radius))
            Circle().stroke(accent.opacity(selected ? 0.9 : 0.5),
                            lineWidth: selected ? 3 : 1.5)
            IconView(spec: mode?.icon ?? .glyph("apps-grid"))
                .foregroundStyle(accent)
                .frame(width: radius * 0.8, height: radius * 0.8)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .onHover { if $0 { viewModel.focus = .center } }
        .onTapGesture { viewModel.focus = .center; onActivate() }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
    }
}
```

- [ ] **Step 5: Implement `RingBezelCanvas.swift`**

```swift
import SwiftUI

struct RingBezelCanvas: View {
    let bezelRadius: CGFloat
    let innerGlowRadius: CGFloat
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)

            func ring(_ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
            ctx.stroke(ring(bezelRadius), with: .color(.gray.opacity(0.35)), lineWidth: 2)
            ctx.stroke(ring(bezelRadius - 10), with: .color(.gray.opacity(0.18)), lineWidth: 1)
            ctx.stroke(ring(innerGlowRadius),
                       with: .color(accent.opacity(0.25)), lineWidth: 1.5)

            // tick marks around the bezel
            let ticks = 120
            for i in 0..<ticks {
                let a = CGFloat(i) / CGFloat(ticks) * 2 * .pi
                let outer = bezelRadius - 2
                let inner = bezelRadius - (i % 10 == 0 ? 10 : 5)
                var p = Path()
                p.move(to: CGPoint(x: c.x + outer * cos(a), y: c.y + outer * sin(a)))
                p.addLine(to: CGPoint(x: c.x + inner * cos(a), y: c.y + inner * sin(a)))
                ctx.stroke(p, with: .color(.gray.opacity(i % 10 == 0 ? 0.5 : 0.28)),
                           lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 6: Replace `RingView.swift` body**

```swift
import SwiftUI

public struct RingView: View {
    @ObservedObject var viewModel: RingViewModel
    @Environment(\.colorScheme) private var scheme
    let onActivate: () -> Void

    public init(viewModel: RingViewModel, onActivate: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onActivate = onActivate
    }

    public static let diameter: CGFloat = 560
    private static let center = CGPoint(x: diameter / 2, y: diameter / 2)
    private static let bezelRadius: CGFloat = 268
    private static let outerRadius: CGFloat = 210
    private static let innerRadius: CGFloat = 120
    private static let centerHubRadius: CGFloat = 62

    public var body: some View {
        let accent = Theme.accent(for: viewModel.currentMode)
        ZStack {
            Circle()
                .fill(Theme.ringPlate(scheme))
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: Self.bezelRadius * 2, height: Self.bezelRadius * 2)

            RingBezelCanvas(bezelRadius: Self.bezelRadius,
                            innerGlowRadius: Self.innerRadius + 42, accent: accent)
            OuterRingView(viewModel: viewModel, center: Self.center,
                          radius: Self.outerRadius, accent: accent, onActivate: onActivate)
            ModeRingView(viewModel: viewModel, center: Self.center,
                         radius: Self.innerRadius, accent: accent, onActivate: onActivate)
            CenterHubView(viewModel: viewModel, radius: Self.centerHubRadius,
                          accent: accent, onActivate: onActivate)
                .position(Self.center)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .scaleEffect(viewModel.isOpen ? 1 : 0.86)
        .opacity(viewModel.isOpen ? 1 : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: viewModel.isOpen)
    }
}
```

> If `RingWindowController` references `RingView.diameter` for panel size (it does),
> the new value `560` flows through automatically.

- [ ] **Step 7: Build verification**

Run: `swift build 2>&1 | tail -20`
Expected: "Build complete!"

- [ ] **Step 8: Manual smoke**

Run: `./scripts/run.sh`, press **⌘⌥⇧+[**.
Expected: full dial with Safari/Notes/Mail/Music/Terminal icons (native), inner
mode ring + gear, glowing center. Arrow keys move the amber selection; ↑/↓ change
ring focus; Return on Safari launches it and closes the ring; selecting the inner
"Web" chip + Return switches the outer ring to Web actions; Esc closes.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "feat: compose full radial UI (tiles, mode ring, hub, bezel) with animation"
```

---

## Task 15: Settings window UI ("Control Ring")

**Files:**
- Create: `Sources/ControlRingKit/Settings/SettingsComponents.swift` (reusable `PaletteRow`, `IconPicker`)
- Create: `Sources/ControlRingKit/Settings/SettingsView.swift`
- Create: `Sources/ControlRingKit/Settings/ModesSidebar.swift`
- Create: `Sources/ControlRingKit/Settings/ModeEditorView.swift`
- Create: `Sources/ControlRingKit/Settings/SlotListView.swift`
- Create: `Sources/ControlRingKit/Settings/ActionInspectorView.swift`
- Create: `Sources/ControlRingKit/Settings/SettingsBottomBar.swift`
- Modify: `Sources/ControlRingKit/Settings/SettingsWindowController.swift` (use `SettingsView`)

All panes edit `store.config` through index bindings; a top-level
`onChange` debounces `store.save()` so edits persist and the ring reflects them on
next open. `PaletteRow` and `IconPicker` are shared by the mode editor and the
action inspector (DRY).

- [ ] **Step 1: Implement `SettingsComponents.swift`**

```swift
import SwiftUI
import AppKit

public struct PaletteRow: View {
    @Binding var color: ColorSpec
    public init(color: Binding<ColorSpec>) { self._color = color }
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Theme.paletteOrder, id: \.self) { key in
                Circle()
                    .fill(Theme.color(.named(key)))
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.primary, lineWidth: isSelected(key) ? 2 : 0))
                    .onTapGesture { color = .named(key) }
            }
            // Custom color (writes ColorSpec.rgba)
            ColorPicker("", selection: customBinding, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 22, height: 22)
        }
    }
    private func isSelected(_ k: String) -> Bool {
        if case .named(let n) = color { return n == k }
        return false
    }
    private var customBinding: Binding<Color> {
        Binding(get: { Theme.color(color) }, set: { color = ColorSpec.from($0) })
    }
}

extension ColorSpec {
    /// Bridges a SwiftUI Color into an sRGB `.rgba` ColorSpec.
    static func from(_ color: Color) -> ColorSpec {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        return .rgba(Double(ns.redComponent), Double(ns.greenComponent),
                     Double(ns.blueComponent), Double(ns.alphaComponent))
    }
}

public struct IconPicker: View {
    @Binding var icon: IconSpec
    let allowAppIcon: Bool
    private let symbols = ["safari","globe","envelope.fill","music.note","terminal.fill",
        "folder.fill","gearshape.fill","chevron.left.forwardslash.chevron.right","star.fill",
        "bolt.fill","calendar","map.fill","network","moon.fill","lock.fill","play.rectangle.fill",
        "square.grid.2x2.fill"]
    public init(icon: Binding<IconSpec>, allowAppIcon: Bool) {
        self._icon = icon; self.allowAppIcon = allowAppIcon
    }
    public var body: some View {
        Menu {
            if allowAppIcon { Button("App Icon") { icon = .appIcon } }
            ForEach(symbols, id: \.self) { s in
                Button { icon = .symbol(s) } label: { Label(s, systemImage: s) }
            }
        } label: {
            IconView(spec: icon)
                .frame(width: 26, height: 26)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.slotPlate))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
```

- [ ] **Step 2: Implement `ModesSidebar.swift`**

```swift
import SwiftUI

struct ModesSidebar: View {
    @ObservedObject var store: ConfigStore
    @Binding var selectedModeIndex: Int
    @Binding var selectedSlotIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Modes")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)

            List(selection: listSelection) {
                ForEach(Array(store.config.modes.enumerated()), id: \.element.id) { idx, mode in
                    row(idx, mode).tag(idx)
                }
                .onMove { store.config.modes.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.sidebar)

            Divider()
            HStack {
                Button { addMode() } label: { Label("Empty Mode", systemImage: "plus") }
                    .buttonStyle(.borderless)
                Spacer()
                Button(role: .destructive) { deleteSelected() } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .disabled(store.config.modes.isEmpty)
            }
            .padding(10)
        }
    }

    private var listSelection: Binding<Int?> {
        Binding(get: { selectedModeIndex },
                set: { selectedModeIndex = $0 ?? 0; selectedSlotIndex = nil })
    }

    private func row(_ idx: Int, _ mode: Mode) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Theme.color(mode.color))
                IconView(spec: mode.icon).foregroundStyle(.white).padding(5)
            }.frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(mode.name)
                if mode.contextual {
                    Text("Contextual — opens for Finder sel…")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text("\(mode.filledCount)").foregroundStyle(.secondary)
        }
    }

    private func addMode() {
        store.config.modes.append(
            Mode(name: "New Mode", icon: .glyph("apps-grid"), color: .named("gray"), actions: []))
        selectedModeIndex = store.config.modes.count - 1
        selectedSlotIndex = nil
    }
    private func deleteSelected() {
        guard store.config.modes.indices.contains(selectedModeIndex) else { return }
        store.config.modes.remove(at: selectedModeIndex)
        selectedModeIndex = max(0, min(selectedModeIndex, store.config.modes.count - 1))
        selectedSlotIndex = nil
    }
}
```

- [ ] **Step 3: Implement `ModeEditorView.swift`**

```swift
import SwiftUI

struct ModeEditorView: View {
    @Binding var mode: Mode
    var onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODE").font(.caption).foregroundStyle(.secondary)
            TextField("Mode name", text: $mode.name).textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    IconPicker(icon: $mode.icon, allowAppIcon: false)
                    Text("Icon").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    PaletteRow(color: $mode.color)
                    Text("Color").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Toggle("Contextual mode (auto-opens for Finder selections)", isOn: $mode.contextual)
                .toggleStyle(.checkbox)

            Button("Clear Mode", action: onClear)
        }
    }
}
```

- [ ] **Step 4: Implement `SlotListView.swift`**

```swift
import SwiftUI

struct SlotListView: View {
    @Binding var mode: Mode
    @Binding var selectedSlotIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("OUTER RING SLOTS")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
            List(selection: $selectedSlotIndex) {
                ForEach(mode.slots) { slot in
                    row(slot).tag(slot.index)
                }
                .onMove(perform: moveSlots)
            }
        }
    }

    /// Reorder actions across the fixed 8 slots, keeping indices 0..7 stable.
    private func moveSlots(_ offsets: IndexSet, _ destination: Int) {
        var actions = mode.slots.map { $0.action }
        actions.move(fromOffsets: offsets, toOffset: destination)
        mode.slots = actions.enumerated().map { Slot(index: $0.offset, action: $0.element) }
    }

    private func row(_ slot: Slot) -> some View {
        HStack(spacing: 10) {
            Text("\(slot.index)").foregroundStyle(.secondary).frame(width: 16)
            if let action = slot.action {
                SlotTile(action: action, selected: false, size: 24)
                Text(action.title)
                Spacer()
                Text(action.type.rawValue.capitalized).foregroundStyle(.secondary)
            } else {
                Image(systemName: "square.dashed").foregroundStyle(.secondary)
                Text("Empty slot").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 5: Implement `ActionInspectorView.swift`**

```swift
import SwiftUI

struct ActionInspectorView: View {
    @Binding var slot: Slot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("ACTION").font(.caption).foregroundStyle(.secondary)
                if let action = actionBinding {
                    form(action)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Empty slot").foregroundStyle(.secondary)
                        Button("Add Action") { slot.action = ActionInspectorView.newAction() }
                    }
                }
            }
            .padding(16)
        }
    }

    private var actionBinding: Binding<Action>? {
        guard slot.action != nil else { return nil }
        return Binding(get: { slot.action! }, set: { slot.action = $0 })
    }

    @ViewBuilder private func form(_ action: Binding<Action>) -> some View {
        TextField("Title", text: action.title).textFieldStyle(.roundedBorder)
        TextField("Subtitle (optional)",
                  text: Binding(get: { action.wrappedValue.subtitle ?? "" },
                                set: { action.wrappedValue.subtitle = $0.isEmpty ? nil : $0 }))
            .textFieldStyle(.roundedBorder)

        Picker("Type", selection: action.type) {
            ForEach(ActionType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }

        switch action.wrappedValue.type {
        case .application:
            field("Bundle ID (e.g. com.apple.Safari)",
                  Binding(get: { action.wrappedValue.bundleID ?? "" },
                          set: { action.wrappedValue.bundleID = $0.isEmpty ? nil : $0 }))
            field("App path (used when no bundle ID)",
                  Binding(get: { action.wrappedValue.appPath ?? "" },
                          set: { action.wrappedValue.appPath = $0.isEmpty ? nil : $0 }))
            argumentsEditor(action)
        case .script:
            Text("Shell command").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: Binding(get: { action.wrappedValue.scriptCommand ?? "" },
                                     set: { action.wrappedValue.scriptCommand = $0 }))
                .frame(height: 80).font(.system(.body, design: .monospaced))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline))
        case .url:
            field("URL",
                  Binding(get: { action.wrappedValue.url ?? "" },
                          set: { action.wrappedValue.url = $0.isEmpty ? nil : $0 }))
        case .folder:
            field("Folder path",
                  Binding(get: { action.wrappedValue.folderPath ?? "" },
                          set: { action.wrappedValue.folderPath = $0.isEmpty ? nil : $0 }))
        }

        Divider()
        Text("PRESENTATION").font(.caption).foregroundStyle(.secondary)
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 4) {
                IconPicker(icon: action.presentation.icon,
                           allowAppIcon: action.wrappedValue.type == .application)
                Text("Icon").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                PaletteRow(color: action.presentation.color)
                Text("Color").font(.caption2).foregroundStyle(.secondary)
            }
        }

        Divider()
        Text("AVAILABILITY").font(.caption).foregroundStyle(.secondary)
        Picker("Shown in", selection: action.availability) {
            Text("General").tag(Availability.general)
            Text("Contextual").tag(Availability.contextual)
            Text("General + contextual").tag(Availability.generalAndContextual)
        }

        Divider()
        Button(role: .destructive) { slot.action = nil } label: { Text("Remove Action") }
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        TextField(title, text: text).textFieldStyle(.roundedBorder)
    }

    private func argumentsEditor(_ action: Binding<Action>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Arguments — one per line").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { action.wrappedValue.arguments.joined(separator: "\n") },
                set: { action.wrappedValue.arguments =
                        $0.split(separator: "\n", omittingEmptySubsequences: false)
                          .map(String.init).filter { !$0.isEmpty } }))
                .frame(height: 60)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline))
        }
    }

    static func newAction() -> Action {
        Action(title: "New Action", type: .application,
               presentation: Presentation(icon: .appIcon, color: .named("blue")))
    }
}
```

- [ ] **Step 6: Implement `SettingsBottomBar.swift`**

```swift
import SwiftUI

struct SettingsBottomBar: View {
    @ObservedObject var store: ConfigStore
    @State private var confirmingRestore = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
            Text("\(store.config.hotkey.displayString)  summons the ring")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reveal Config") { store.revealInFinder() }
            Button("Restore Defaults") { confirmingRestore = true }
        }
        .padding(12)
        .confirmationDialog("Restore default configuration?",
                            isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Restore Defaults", role: .destructive) { store.restoreDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This overwrites your current modes and slots.")
        }
    }
}
```

- [ ] **Step 7: Implement `SettingsView.swift`**

```swift
import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    @State private var selectedModeIndex = 0
    @State private var selectedSlotIndex: Int? = nil
    @State private var debouncer = Debouncer()

    public init(store: ConfigStore) { self.store = store }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ModesSidebar(store: store,
                             selectedModeIndex: $selectedModeIndex,
                             selectedSlotIndex: $selectedSlotIndex)
                    .frame(width: 232)
                Divider()
                middleColumn.frame(minWidth: 380, maxWidth: .infinity)
                Divider()
                inspectorColumn.frame(width: 320)
            }
            Divider()
            SettingsBottomBar(store: store)
        }
        .frame(minWidth: 960, minHeight: 620)
        .onChange(of: store.config) { _ in debouncer.call { store.save() } }
        .onAppear(perform: clampSelection)
    }

    @ViewBuilder private var middleColumn: some View {
        if store.config.modes.indices.contains(selectedModeIndex) {
            VStack(spacing: 0) {
                ModeEditorView(mode: modeBinding(selectedModeIndex)) { clearMode(selectedModeIndex) }
                    .padding(16)
                Divider()
                SlotListView(mode: modeBinding(selectedModeIndex),
                             selectedSlotIndex: $selectedSlotIndex)
            }
        } else { placeholder("No mode selected") }
    }

    @ViewBuilder private var inspectorColumn: some View {
        if let si = selectedSlotIndex,
           store.config.modes.indices.contains(selectedModeIndex),
           store.config.modes[selectedModeIndex].slots.indices.contains(si) {
            ActionInspectorView(slot: slotBinding(selectedModeIndex, si))
        } else { placeholder("Select a slot to edit its action") }
    }

    private func placeholder(_ text: String) -> some View {
        VStack { Spacer(); Text(text).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modeBinding(_ i: Int) -> Binding<Mode> {
        Binding(get: { store.config.modes[i] }, set: { store.config.modes[i] = $0 })
    }
    private func slotBinding(_ m: Int, _ s: Int) -> Binding<Slot> {
        Binding(get: { store.config.modes[m].slots[s] },
                set: { store.config.modes[m].slots[s] = $0 })
    }
    private func clearMode(_ i: Int) {
        for s in store.config.modes[i].slots.indices { store.config.modes[i].slots[s].action = nil }
    }
    private func clampSelection() {
        if store.config.modes.isEmpty { selectedModeIndex = 0 }
        else { selectedModeIndex = min(max(0, selectedModeIndex), store.config.modes.count - 1) }
    }
}
```

- [ ] **Step 8: Point the controller at `SettingsView`**

In `SettingsWindowController.rootView()` replace the placeholder with:
```swift
    func rootView() -> AnyView { AnyView(SettingsView(store: store)) }
```

- [ ] **Step 9: Build verification**

Run: `swift build 2>&1 | tail -20`
Expected: "Build complete!"

- [ ] **Step 10: Manual smoke**

Run: `./scripts/run.sh`; open **Settings…** from the menu bar.
Expected: three-pane editor; select Apps → slot 0 (Safari) loads into the inspector;
change its color → the ring tile updates on next summon; add an Empty Mode; toggle
Contextual; Reveal Config opens Finder at `config.json`. Confirm edits persist after
quitting and relaunching.

- [ ] **Step 11: Commit**

```bash
git add -A && git commit -m "feat: build Control Ring settings window (modes, slots, action inspector)"
```

---

## Task 16: Packaging — assemble a signed `ControlRing.app`

**Files:**
- Create: `Resources/Info.plist`
- Create: `scripts/build-app.sh`
- Create: `scripts/make-icon.sh` (optional icon; safe to skip if no source art)

- [ ] **Step 1: Create `Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Control Ring</string>
    <key>CFBundleDisplayName</key><string>Control Ring</string>
    <key>CFBundleIdentifier</key><string>com.mikedelgaudio.ControlRing</string>
    <key>CFBundleExecutable</key><string>ControlRing</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 2: Create `scripts/build-app.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ControlRing"
CONFIG="${1:-release}"
BIN_DIR=".build/${CONFIG}"
OUT="build/${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

echo "==> assembling ${OUT}"
rm -rf "${OUT}"
mkdir -p "${OUT}/Contents/MacOS" "${OUT}/Contents/Resources"
cp "${BIN_DIR}/${APP_NAME}" "${OUT}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${OUT}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${OUT}/Contents/Resources/AppIcon.icns"
fi

echo "==> ad-hoc codesign"
codesign --force --deep --sign - "${OUT}"

echo "==> done: ${OUT}"
echo "Launch with: open \"${OUT}\""
```

- [ ] **Step 3: Create `scripts/make-icon.sh` (optional)**

```bash
#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from Resources/AppIcon-1024.png (if present).
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="Resources/AppIcon-1024.png"
[ -f "$SRC" ] || { echo "No $SRC; skipping icon."; exit 0; }
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512; do
    sips -z $sz $sz "$SRC" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
    d=$((sz*2)); sips -z $d $d "$SRC" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "Resources/AppIcon.icns"
echo "Wrote Resources/AppIcon.icns"
```

- [ ] **Step 4: Make executable and build the app**

Run:
```bash
chmod +x scripts/build-app.sh scripts/make-icon.sh
./scripts/build-app.sh 2>&1 | tail -20
```
Expected: "done: build/ControlRing.app".

- [ ] **Step 5: Launch the bundle and smoke-test**

Run: `open build/ControlRing.app`
Expected: no Dock icon; a menu-bar item appears. Press **⌘⌥⇧+[** → ring appears
over other apps. Launch Safari from a slot. Open Settings from the menu bar.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "build: assemble and ad-hoc sign ControlRing.app bundle"
```

---

## Task 17: End-to-end verification, README, and cleanup

**Files:**
- Create: `README.md`

- [ ] **Step 1: Run the full test suite**

Run: `swift test 2>&1 | tail -25`
Expected: all tests pass (CoreSpecs, Config, DefaultConfig, ConfigStore, RingGeometry,
RingViewModel, ActionRunner, HotKeyCarbon). If any fail, fix before continuing.

- [ ] **Step 2: Full manual acceptance pass** (against the spec's success criteria)

Run `./scripts/build-app.sh && open build/ControlRing.app`, then verify:
  - Summon with **⌘⌥⇧+[**; ring animates in centered on the active screen.
  - Keyboard: ←/→ rotate; ↑/↓ move focus outer⇄inner⇄center; **1–8** jump; **Return**
    launches; **Esc** closes; click-outside closes.
  - Apps show **native icons**; scripts/urls show symbol-on-color tiles.
  - Switch modes on the inner ring; outer slots update.
  - Settings: edit a slot's action/color/type; **persists** across relaunch;
    Reveal Config + Restore Defaults work.
  - Toggle macOS **light/dark** (System Settings) → ring surfaces adapt.
  - Launch a **script** action (e.g., "Localhost") and a **URL** action.

- [ ] **Step 3: Write `README.md`**

Include: what it is, the hotkey, `scripts/run.sh` (dev), `scripts/build-app.sh`
(release bundle), `swift test`, config location
(`~/Library/Application Support/ControlRing/config.json`), and the "no Xcode
required — Command Line Tools only" note. Document keyboard shortcuts and the
deferred phases (search, contextual mode).

- [ ] **Step 4: Confirm `.gitignore` excludes build artifacts**

Ensure `.gitignore` contains `.build/`, `build/`, `*.app/`, `.DS_Store`,
`config.json`. (Root `.gitignore` already has most; add `build/` if missing.)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "docs: add README and finalize v1 verification"
```

---

## Definition of Done

- `swift test` green; `swift build -c release` clean.
- `./scripts/build-app.sh` produces a launchable, ad-hoc-signed `ControlRing.app`.
- ⌘⌥⇧+[ summons an animated radial launcher that launches apps (native icons) and
  scripts, switches modes, is fully keyboard-navigable, and respects macOS theming.
- Settings window edits modes/slots/actions and persists to JSON (Reveal Config /
  Restore Defaults functional).
- Architecture is DRY and layered: all logic in `ControlRingKit` behind seams
  (`ProcessRunning`, app-URL resolver, `ActivationIntent`), reused geometry/theme/
  tile components, with unit tests covering the deterministic core.

## Notes for the Implementer

- Follow tasks in order; each ends green except the intentional cross-file gap
  called out in Task 12 (resolved in Task 13).
- Some SwiftUI code may need small compiler fixups (e.g. `Binding` inference); run
  the build after each UI task and address diagnostics before committing.
- Do NOT add features from the deferred list (search, contextual auto-open); the
  model already carries their fields for the next phase.
