# Control Ring — v1 Design

**Status:** Approved (pending spec review)
**Date:** 2026-07-10
**Author:** @mikedelgaudio (with Copilot)

## Summary

Control Ring is a native macOS SwiftUI **radial launcher** — a Launchpad-like
app expressed as a circular dial. The user summons it with a global hotkey
(**⌘⌥⇧+[**), then launches applications and scripts from an outer ring of slots,
switches between **modes** (Apps / Web / Dev / System …) on an inner ring, and
customizes everything from a settings window titled **"Control Ring."** The whole
surface is drivable by **mouse or keyboard** and respects the macOS light/dark
theme.

v1 explicitly **excludes** the Spotlight-style fuzzy search overlay and the
contextual/Finder-selection auto-open behavior, but the data model keeps forward-
compatible fields (`contextual`, `availability`) so those phases drop in later.

## Goals

- Summon a radial launcher instantly with **⌘⌥⇧+[** from anywhere.
- Launch **applications** (native app icon shown) and **scripts/shell commands**
  from outer-ring slots.
- Support **multiple modes**, each with its own name, icon, color, and 8 slots,
  chosen from an inner ring.
- Provide a **settings window** to edit modes, slots, and actions, matching the
  reference screenshots.
- Be **fully keyboard-navigable** (arrow keys move around the rings; Return
  activates).
- **Respect the macOS theme** (light/dark) and accent.
- **Persist** configuration to disk as JSON with Reveal Config / Restore Defaults.
- Build and run entirely from the **Command Line Tools** toolchain (no Xcode).

## Non-Goals (v1)

- Spotlight-style fuzzy **search** overlay (later phase).
- **Contextual mode** auto-opening for Finder selections (later phase; fields kept).
- Sandboxing / App Store distribution / notarization.
- iCloud sync of config.
- Multi-monitor per-screen configuration (ring simply opens on the active screen).

## Toolchain Constraints (validated)

- Only **Command Line Tools** are installed (no Xcode → no `xcodebuild`).
- **Swift 6.2**, macOS SDK 26 available via `xcrun --sdk macosx`.
- Smoke-tested: an SPM `executableTarget` importing **SwiftUI + AppKit +
  Carbon.HIToolbox** compiles and runs under CLT. `NSHostingView` works.
  `kVK_ANSI_LeftBracket` = **33**.
- Therefore the app bootstraps `NSApplication` in code and hosts SwiftUI via
  `NSHostingView`; no `@main App` project, no Interface Builder, no `.xcodeproj`.

## Architecture

### Process shape
- A **menu-bar accessory app** (`LSUIElement = YES`): no Dock icon, a status-bar
  item is the always-running host.
- The host (`AppDelegate`) owns: the **hotkey manager**, the **ring window**, the
  **settings window**, and the **config store**.

### Build & packaging
- **Swift Package Manager** executable target `ControlRing`.
- `scripts/build-app.sh`:
  1. `swift build -c release`.
  2. Assemble `ControlRing.app/Contents/{MacOS,Resources}`.
  3. Copy the release binary and a generated `Info.plist`
     (`LSUIElement=YES`, bundle id `com.mikedelgaudio.ControlRing`, min macOS 13).
  4. Generate `AppIcon.icns` from a source PNG via `sips` + `iconutil`.
  5. Ad-hoc `codesign` the bundle so it launches cleanly.
  6. Print the path; `open` it.
- `scripts/run.sh` for a fast debug loop (`swift build && ./.build/debug/ControlRing`).

### Module / file layout
```
Package.swift
Sources/ControlRing/
  App/
    main.swift                 // NSApplication bootstrap, accessory policy
    AppDelegate.swift          // status item, window mgmt, wiring
  Hotkey/
    HotKeyManager.swift        // Carbon RegisterEventHotKey wrapper + callback
  Model/
    Config.swift               // top-level Codable config
    Mode.swift, Slot.swift, Action.swift, ActionType.swift
    Presentation.swift, HotKeySpec.swift, IconSpec.swift, ColorSpec.swift
    ConfigStore.swift          // load/save JSON, defaults, reveal, observable
  Launcher/
    ActionRunner.swift         // launch app / run script / open url / open folder
    ProcessRunning.swift       // protocol seam for testing script execution
  Ring/
    RingWindow.swift           // borderless non-activating NSPanel host
    RingViewModel.swift        // open/close, focus ring, selection, current mode
    RingView.swift             // composes the whole dial
    CenterHubView.swift, ModeRingView.swift, OuterRingView.swift, SlotView.swift
    RingGeometry.swift         // angle/position math for N slots
    RingBezelCanvas.swift      // decorative bezel + glow (SwiftUI Canvas)
  Settings/
    SettingsWindow.swift
    SettingsView.swift         // 3-pane Control Ring editor
    ModesSidebar.swift, ModeEditorView.swift, SlotListView.swift,
    ActionInspectorView.swift, SettingsBottomBar.swift
  Theme/
    Theme.swift                // semantic colors, appearance-aware, accent tinting
  Util/
    AppIconResolver.swift      // NSWorkspace icon(forFile:) via bundle id/path
    SFSymbol.swift, Debounce.swift
Sources/... (Resources)/
  AppIcon source assets
Tests/ControlRingTests/
  ConfigCodableTests.swift, RingGeometryTests.swift,
  ActionRunnerTests.swift, ConfigStoreTests.swift
scripts/
  build-app.sh, run.sh
docs/superpowers/specs/2026-07-10-control-ring-design.md
```

## Data Model

Persisted to `~/Library/Application Support/ControlRing/config.json`
(atomic write; created with defaults on first launch).

```text
Config {
  version: Int                       // schema version, currently 1
  hotkey: HotKeySpec                 // { keyCode: Int, modifiers: [String] }
  modes: [Mode]
  settings: Settings                 // { ringDiameter?, showInMenuBar, ... minimal }
}

Mode {
  id: UUID
  name: String                       // "Apps"
  icon: IconSpec                     // SF Symbol name or built-in glyph id
  color: ColorSpec                   // mode accent (from a fixed palette + custom)
  contextual: Bool                   // reserved for later phase (persisted, unused in v1)
  slots: [Slot]                      // fixed length 8; empties allowed
}

Slot {
  index: Int                         // 0..7, position around the outer ring
  action: Action?                    // nil => empty "+" slot
}

Action {
  id: UUID
  title: String                      // "Safari"
  subtitle: String?                  // optional
  type: ActionType                   // application | script | url | folder
  bundleID: String?                  // com.apple.Safari (application)
  appPath: String?                   // used when bundleID is nil (application)
  arguments: [String]                // documents / arguments, one per line
  scriptCommand: String?             // shell command or .sh path (script)
  url: String?                       // (url)
  folderPath: String?                // (folder)
  presentation: Presentation         // { icon: IconSpec, color: ColorSpec }
  availability: Availability         // general | contextual | generalAndContextual
}

ActionType   = application | script | url | folder
Availability = general | contextual | generalAndContextual
IconSpec     = .appIcon | .symbol(name) | .glyph(builtinId)
ColorSpec    = named palette entry or rgba
HotKeySpec   = { keyCode: Int, modifiers: [String] }   // default {33, [command,option,shift]}
```

**Icon resolution:** application actions display the **native app icon**
(`NSWorkspace.shared.icon(forFile:)`, path resolved from `bundleID` via
`urlForApplication(withBundleIdentifier:)`, falling back to `appPath`). Script /
url / folder actions render an SF-Symbol glyph on a rounded color tile
(`presentation.color`).

**Defaults** (first-run) mirror the reference screenshots: an **Apps** mode with
Safari, Notes, Mail, Music, Terminal (plus empty slots), and additional Web / Dev
/ System modes with representative entries.

## Ring Window & Presentation

- Borderless, transparent **`NSPanel`**: `styleMask = [.borderless, .nonactivatingPanel]`,
  `level = .floating`, `isOpaque = false`, `backgroundColor = .clear`,
  `hasShadow = false`, `collectionBehavior` includes `.canJoinAllSpaces` and
  `.fullScreenAuxiliary`. Hosts `RingView` via `NSHostingView`.
- Centered on the screen that currently contains the mouse (active screen).
- **Open animation:** spring scale (≈0.85→1.0) + fade; outer slots stagger-rotate
  into place. **Close:** reverse, triggered by Esc, click-outside, launching an
  action, or losing key focus.
- The panel becomes key while shown so it receives keyboard events, and resigns /
  orders out on close. Because it is `.nonactivatingPanel`, it overlays the
  frontmost app without a heavy app switch; the previously-active app is restored
  on close so launched actions target the right context.

## Ring UI Composition

- **CenterHubView:** current mode glyph + amber glow; activating it opens Settings.
- **ModeRingView (inner):** one wedge per mode, plus a gear (Settings) and an
  empty-mode "+" affordance. Selecting a wedge switches `currentMode`.
- **OuterRingView (outer):** 8 `SlotView`s placed by `RingGeometry`. Each slot is
  an action tile (native app icon or symbol-on-color tile) or an empty "+" slot.
- **RingBezelCanvas:** decorative outer bezel, tick marks, and concentric glow
  rings drawn in a SwiftUI `Canvas` (cheap, non-interactive).
- A small **amber triangle pointer** marks the current selection.
- **Performance:** only ~10–18 interactive views; decorative geometry is Canvas.
  Spring animations via SwiftUI; targets ProMotion 120fps.

## Keyboard Navigation

`RingViewModel` holds `focus: {outer, inner, center}` and a `selectionIndex`.

- **← / →** rotate `selectionIndex` around the currently focused ring
  (wraps around).
- **↑ / ↓** move focus between rings: `outer → inner → center` and back.
- **Return / Space** activates the current selection:
  - outer slot → run its action (no-op on empty),
  - inner wedge → switch mode (or open Settings for the gear),
  - center → open Settings.
- **1–8** jump directly to an outer slot and focus the outer ring.
- **Esc** closes the ring.
- Mouse hover and keyboard selection **share the same highlight state**, so the
  amber pointer follows whichever input the user last used.

## Launching (`ActionRunner`)

- **application:** resolve bundle id → app URL (fallback `appPath`); open via
  `NSWorkspace.shared.openApplication(at:configuration:)`, passing `arguments`
  as document URLs when present.
- **script:** run through an injected `ProcessRunning` seam — default
  implementation executes `/bin/sh -lc "<scriptCommand>"` (or the `.sh` path) via
  `Process`, detached, capturing failure. The seam makes command construction
  unit-testable without spawning processes.
- **url:** `NSWorkspace.shared.open(URL)`.
- **folder:** open in Finder via `NSWorkspace`.
- On success the ring **closes**; failures are logged and surfaced as a brief
  transient message (no modal). The previously-active app is restored before the
  action runs so it targets the correct foreground context.

## Settings Window ("Control Ring")

A standard titled `NSWindow` hosting a **three-pane** SwiftUI layout that mirrors
the reference screenshot:

- **Modes sidebar (left):** list of modes with per-mode item count; add
  ("+ Empty Mode"), reorder, and delete.
- **Mode editor (center-top):** mode `name`, **Icon** picker, **Color** picker
  (fixed palette dots + custom), **Contextual mode** toggle (reserved), and
  **Clear Mode**.
- **Outer Ring Slots (center-bottom):** the 8 slots with icon, title, type badge,
  and controls to assign / clear / reorder; selecting a slot loads it into the
  inspector.
- **Action inspector (right):** `title`, `subtitle`, **Type** dropdown, **bundle
  ID**, **app path**, **arguments** (one per line), **Presentation** (icon +
  color), **Availability** ("Shown in") dropdown.
- **Bottom bar:** hotkey hint (`⌘⌥⇧[ summons the ring`), **Reveal Config**
  (reveals `config.json` in Finder), **Restore Defaults** (rewrites defaults after
  confirmation).
- Edits **live-save** through `ConfigStore`; the ring reflects changes on next
  open. `ConfigStore` is an `ObservableObject` shared by ring and settings.

## Theming

- `Theme` exposes semantic colors and reads `NSApp.effectiveAppearance`, so ring
  surfaces adapt to **light/dark**. Base surfaces use material/vibrancy; amber is
  the brand accent, **tinted per-mode** by the active mode's `color`.
  `controlAccentColor` is used where the system accent is appropriate.
- The settings window uses standard AppKit-themed controls, so it matches system
  appearance automatically.

## Persistence & First Run

- `ConfigStore.load()` reads `config.json`; if missing/corrupt it writes and loads
  **defaults** (backing up a corrupt file to `config.corrupt-<timestamp>.json`).
- Writes are **atomic** (`Data.write(to:options:.atomic)`), debounced during rapid
  settings edits.
- **Reveal Config** selects the file in Finder; **Restore Defaults** overwrites it.

## Permissions & Security

- **No special permissions** for the Carbon hotkey (`RegisterEventHotKey`).
- App is **not sandboxed** (it launches arbitrary apps/scripts and reads a config
  file), consistent with local, non-App-Store distribution.
- Script actions run user-authored commands with the user's own privileges; the
  app adds no elevation. No secrets are stored in config.

## Testing Strategy

SPM `Tests/ControlRingTests` covering the deterministic logic:

- **ConfigCodableTests** — encode/decode round-trip; defaults are valid; unknown/
  missing fields tolerated (forward-compat for `contextual`/`availability`).
- **RingGeometryTests** — slot angles/positions for N=8 (and edge counts); wrap-
  around selection math for keyboard nav.
- **ActionRunnerTests** — command/argument construction for each `ActionType`
  using a fake `ProcessRunning`; verifies script quoting and app-URL resolution
  logic (no real process spawned).
- **ConfigStoreTests** — load-missing-writes-defaults, atomic save round-trip,
  corrupt-file backup behavior (using a temp directory).

UI is kept thin over `RingViewModel` / `ConfigStore`, whose state transitions
(focus movement, selection wrap, mode switching) are unit-testable.

## Build / Run / Verify

- `scripts/run.sh` — `swift build && ./.build/debug/ControlRing` for iteration.
- `scripts/build-app.sh` — produce the signed `ControlRing.app`.
- `swift test` — run the unit suite.
- Manual smoke: launch, press ⌘⌥⇧+[, ring appears; arrow-navigate; Return launches
  Safari; open Settings, edit a slot, confirm the ring reflects it; toggle system
  appearance and confirm theming.

## Phasing (post-v1, for context only)

1. **Search:** Spotlight-style fuzzy overlay filtering actions across modes.
2. **Contextual mode:** auto-open a designated mode for Finder selections, honoring
   `availability` and `contextual` fields already in the model.
