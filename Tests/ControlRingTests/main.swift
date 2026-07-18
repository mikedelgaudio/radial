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
}

print("ControlRingTests — checks: \(XCTestRegistry.checks), failures: \(XCTestRegistry.failures.count)")
for f in XCTestRegistry.failures { print("  FAIL \(f)") }
if XCTestRegistry.failures.isEmpty { print("ALL TESTS PASSED") }
exit(XCTestRegistry.failures.isEmpty ? 0 : 1)
