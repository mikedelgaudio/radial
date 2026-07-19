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
}
