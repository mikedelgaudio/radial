import Foundation
import XCTest

func run(_ name: String, _ body: () throws -> Void) {
    do { try body() } catch { XCTestRegistry.record("\(name) threw \(error)", #file, #line) }
}

MainActor.assumeIsolated {
    // Task 1
    let coreSpecs = CoreSpecsCodableTests()
    run("CoreSpecs.test_kit_links", coreSpecs.test_kit_links)
}

print("ControlRingTests — checks: \(XCTestRegistry.checks), failures: \(XCTestRegistry.failures.count)")
for f in XCTestRegistry.failures { print("  FAIL \(f)") }
if XCTestRegistry.failures.isEmpty { print("ALL TESTS PASSED") }
exit(XCTestRegistry.failures.isEmpty ? 0 : 1)
