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
