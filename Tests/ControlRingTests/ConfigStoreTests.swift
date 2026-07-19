import XCTest
@testable import ControlRingKit

@MainActor
final class ConfigStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("cr-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func test_first_load_writes_defaults() throws {
        let dir = tempDir()
        let store = ConfigStore(directory: dir)
        store.load()
        XCTAssertEqual(store.config.modes.map(\.name), ["Apps", "Web", "Dev", "System"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func test_save_then_load_roundtrips() throws {
        let dir = tempDir()
        let a = ConfigStore(directory: dir); a.load()
        a.config.modes[0].name = "Renamed"
        a.save()
        let b = ConfigStore(directory: dir); b.load()
        XCTAssertEqual(b.config.modes[0].name, "Renamed")
    }

    func test_corrupt_file_is_backed_up_and_defaults_loaded() throws {
        let dir = tempDir()
        let store = ConfigStore(directory: dir)
        try "not json".data(using: .utf8)!.write(to: store.fileURL)
        store.load()
        XCTAssertEqual(store.config.modes.map(\.name), ["Apps", "Web", "Dev", "System"])
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("config.corrupt-") }
        XCTAssertEqual(backups.count, 1)
    }

    func test_restoreDefaults_overwrites() throws {
        let dir = tempDir()
        let store = ConfigStore(directory: dir); store.load()
        store.config.modes = []
        store.save()
        store.restoreDefaults()
        XCTAssertEqual(store.config.modes.map(\.name), ["Apps", "Web", "Dev", "System"])
    }
}
