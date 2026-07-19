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
