import AppKit

public enum AppIconResolver {
    private static var cache: [String: NSImage] = [:]

    public static func appImage(for action: Action) -> NSImage? {
        guard action.type == .application else { return nil }
        let key = action.bundleID ?? action.appPath ?? action.title
        if let hit = cache[key] { return hit }
        var url: URL?
        if let bundleID = action.bundleID {
            url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        }
        if url == nil, let path = action.appPath, !path.isEmpty {
            url = URL(fileURLWithPath: path)
        }
        guard let url else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[key] = image
        return image
    }
}
