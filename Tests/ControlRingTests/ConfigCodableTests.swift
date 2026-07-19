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
