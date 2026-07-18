// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ControlRing",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ControlRingKit",
            path: "Sources/ControlRingKit",
            swiftSettings: [.unsafeFlags(["-enable-testing"])]  // enables @testable
        ),
        .executableTarget(
            name: "ControlRing",
            dependencies: ["ControlRingKit"],
            path: "Sources/ControlRing"
        ),
        // Test runner is a plain executable (CLT has no XCTest/Testing module).
        .target(name: "XCTest", path: "Tests/XCTestShim"),
        .executableTarget(
            name: "ControlRingTests",
            dependencies: ["ControlRingKit", "XCTest"],
            path: "Tests/ControlRingTests"
        ),
    ]
)
