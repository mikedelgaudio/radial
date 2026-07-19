import Foundation
import XCTest

func run(_ name: String, _ body: () throws -> Void) {
    do { try body() } catch { XCTestRegistry.record("\(name) threw \(error)", #file, #line) }
}

MainActor.assumeIsolated {
    // Task 2 — CoreSpecsCodableTests
    let coreSpecs = CoreSpecsCodableTests()
    run("CoreSpecs.test_kit_links", coreSpecs.test_kit_links)
    run("CoreSpecs.test_colorSpec_roundTrips_named_and_rgba", coreSpecs.test_colorSpec_roundTrips_named_and_rgba)
    run("CoreSpecs.test_iconSpec_roundTrips_all_cases", coreSpecs.test_iconSpec_roundTrips_all_cases)
    run("CoreSpecs.test_hotKeySpec_default_is_cmd_opt_shift_leftBracket", coreSpecs.test_hotKeySpec_default_is_cmd_opt_shift_leftBracket)
    run("CoreSpecs.test_actionType_and_availability_are_string_codable", coreSpecs.test_actionType_and_availability_are_string_codable)

    // Task 3 & 4 — ConfigCodableTests
    let configCodable = ConfigCodableTests()
    run("ConfigCodable.test_action_roundTrips", configCodable.test_action_roundTrips)
    run("ConfigCodable.test_action_defaults_when_optional_fields_missing", configCodable.test_action_defaults_when_optional_fields_missing)
    run("ConfigCodable.test_mode_normalizes_to_eight_slots", configCodable.test_mode_normalizes_to_eight_slots)
    run("ConfigCodable.test_config_roundTrips", configCodable.test_config_roundTrips)
    run("ConfigCodable.test_mode_defaults_contextual_false_when_missing", configCodable.test_mode_defaults_contextual_false_when_missing)
}

print("ControlRingTests — checks: \(XCTestRegistry.checks), failures: \(XCTestRegistry.failures.count)")
for f in XCTestRegistry.failures { print("  FAIL \(f)") }
if XCTestRegistry.failures.isEmpty { print("ALL TESTS PASSED") }
exit(XCTestRegistry.failures.isEmpty ? 0 : 1)
