import Foundation
import AppKit

public struct ActionRunner {
    public var resolveAppURL: (Action) -> URL?
    public var processRunner: ProcessRunning

    public init(resolveAppURL: @escaping (Action) -> URL? = ActionRunner.defaultAppResolver,
                processRunner: ProcessRunning = SystemProcessRunner()) {
        self.resolveAppURL = resolveAppURL
        self.processRunner = processRunner
    }

    public static let defaultAppResolver: (Action) -> URL? = { action in
        if let bundleID = action.bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        if let path = action.appPath, !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    public func plan(for action: Action) -> LaunchPlan {
        switch action.type {
        case .application:
            guard let url = resolveAppURL(action) else {
                return .failure("Could not resolve application \(action.bundleID ?? action.appPath ?? action.title)")
            }
            return .application(appURL: url, arguments: action.arguments)
        case .script:
            let cmd = (action.scriptCommand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cmd.isEmpty else { return .failure("Empty script command") }
            return .script(executable: "/bin/sh", arguments: ["-lc", cmd])
        case .url:
            guard let raw = action.url, let url = URL(string: raw) else {
                return .failure("Invalid URL")
            }
            return .openURL(url)
        case .folder:
            guard let path = action.folderPath, !path.isEmpty else {
                return .failure("Empty folder path")
            }
            return .openFolder(URL(fileURLWithPath: path))
        }
    }

    /// Executes the plan. Returns nil on success or an error message.
    @discardableResult
    @MainActor
    public func run(_ action: Action) -> String? {
        switch plan(for: action) {
        case .application(let url, let args):
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.arguments = args
            NSWorkspace.shared.openApplication(at: url, configuration: cfg)
            return nil
        case .script(let exe, let args):
            do { try processRunner.run(executable: exe, arguments: args); return nil }
            catch { return "Script failed: \(error.localizedDescription)" }
        case .openURL(let url):
            NSWorkspace.shared.open(url); return nil
        case .openFolder(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url]); return nil
        case .failure(let msg):
            return msg
        }
    }
}
