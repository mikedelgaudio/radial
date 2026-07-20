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

    func test_hotKeySpec_default_is_option_space() {
        let hk = HotKeySpec.default
        XCTAssertEqual(hk.keyCode, 49) // kVK_Space
        XCTAssertEqual(Set(hk.modifiers), ["option"])
    }

    func test_actionType_and_availability_are_string_codable() throws {
        try roundTrip(ActionType.application)
        try roundTrip(Availability.generalAndContextual)
        let data = try JSONEncoder().encode(ActionType.script)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"script\"")
    }
}
