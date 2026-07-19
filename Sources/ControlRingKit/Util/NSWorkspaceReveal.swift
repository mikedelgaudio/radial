import AppKit
enum NSWorkspaceReveal {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
