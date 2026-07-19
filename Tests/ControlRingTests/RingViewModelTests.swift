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

    func test_activate_inner_addMode_item_returns_addMode() {
        let m = vm()
        m.focus = .inner
        m.innerIndex = m.addModeInnerIndex // the "+" item, just before Settings
        XCTAssertEqual(m.activate(), .addMode)
    }

    func test_activate_center_opens_settings() {
        let m = vm()
        m.focus = .center
        XCTAssertEqual(m.activate(), .openSettings)
    }
}
