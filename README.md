# Control Ring

Control Ring is a native macOS SwiftUI radial launcher: Launchpad-as-a-dial. Summon it with a global hotkey, rotate through an outer ring of actions, switch modes from the inner ring, and launch apps, scripts, URLs, and folders without leaving the keyboard.

## Features

- Native macOS SwiftUI ring UI with macOS light/dark theming.
- Global summon hotkey: **⌘⌥⇧+[**.
- Outer-ring actions for:
  - applications, with native app icons when available;
  - shell scripts;
  - URLs;
  - folders.
- Multiple modes via the inner ring; switching modes updates the outer slots.
- **Control Ring** settings window for editing modes, slots, and actions.
- Action inspector for app bundle IDs/paths and arguments, script commands, URLs, folders, availability, icons, palette colors, and custom colors.
- Settings controls for **Reveal Config** and **Restore Defaults**.
- Menu bar status item with summon, settings, config, defaults, and quit actions.

## Keyboard and dismissal

When the ring is open:

| Input | Action |
| --- | --- |
| ← / → | Rotate selection within the focused ring |
| ↑ / ↓ | Move focus outer ⇄ inner ⇄ center |
| Return / Space | Activate the selected slot, mode, or center settings hub |
| 1–8 | Jump to an outer-ring slot |
| Esc | Close the ring |
| Click outside / resign key focus | Close the ring |

## Build and run

Development run:

```bash
./scripts/run.sh
```

Release `.app` bundle:

```bash
./scripts/build-app.sh
open build/ControlRing.app
```

The release script builds with SwiftPM, assembles `build/ControlRing.app`, and ad-hoc signs it.

## Tests

Run the test executable directly:

```bash
swift build && ./.build/debug/ControlRingTests
```

Expected success output includes `ALL TESTS PASSED`.

## Requirements / Toolchain

- macOS 13 or newer.
- Swift Package Manager under Apple's Command Line Tools.
- **Command Line Tools only — no Xcode required.**

Because the Command Line Tools toolchain does not ship the XCTest/Testing module, this project uses an executable test target with a lightweight shim. Use `swift build && ./.build/debug/ControlRingTests`; do not use `swift test` under CLT.

## Configuration

Control Ring stores user configuration at:

```text
~/Library/Application Support/ControlRing/config.json
```

Use **Reveal Config** from the settings window or status menu to open the config location in Finder. Use **Restore Defaults** to overwrite the current modes and slots with the built-in defaults.

## Roadmap / Deferred work

- Spotlight-style fuzzy search.
- Contextual auto-open based on Finder selection.
