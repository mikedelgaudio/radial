import Foundation
import Combine

@MainActor
public final class ConfigStore: ObservableObject {
    @Published public var config: Config = Config(modes: [])
    public let directory: URL

    public var fileURL: URL { directory.appendingPathComponent("config.json") }

    /// Production convenience: ~/Library/Application Support/ControlRing
    public static func applicationSupport() -> ConfigStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ConfigStore(directory: base.appendingPathComponent("ControlRing", isDirectory: true))
    }

    public init(directory: URL) { self.directory = directory }

    public func load() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            config = DefaultConfig.make(); writeToDisk(); return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            config = try JSONDecoder().decode(Config.self, from: data)
            migrate()
        } catch {
            backupCorruptFile()
            config = DefaultConfig.make()
            writeToDisk()
        }
    }

    /// One-time upgrades for existing config files. Only rewrites the hotkey when it
    /// still matches the original v1 default, so a user's custom hotkey is never touched.
    private func migrate() {
        if config.hotkey == HotKeySpec.legacyDefault {
            config.hotkey = .default
            writeToDisk()
        }
    }

    public func save() { writeToDisk() }

    public func restoreDefaults() {
        config = DefaultConfig.make()
        writeToDisk()
    }

    public func revealInFinder() {
        NSWorkspaceReveal.reveal(fileURL)
    }

    private func writeToDisk() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("ControlRing: failed to write config: \(error)")
        }
    }

    private func backupCorruptFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = directory.appendingPathComponent("config.corrupt-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: dest)
    }
}
