import SwiftUI

public enum Glyph {
    /// Built-in glyph ids map to SF Symbols so the whole app stays vector.
    public static func symbolName(_ id: String) -> String {
        switch id {
        case "apps-grid": return "square.grid.2x2.fill"
        case "code":      return "chevron.left.forwardslash.chevron.right"
        case "folder":    return "folder.fill"
        case "gear":      return "gearshape.fill"
        case "globe":     return "globe"
        default:          return "app.dashed"
        }
    }
}

public struct IconView: View {
    public let spec: IconSpec
    public var appImage: NSImage?   // supplied for .appIcon (resolved by caller)
    public init(spec: IconSpec, appImage: NSImage? = nil) {
        self.spec = spec; self.appImage = appImage
    }
    public var body: some View {
        switch spec {
        case .appIcon:
            if let appImage {
                Image(nsImage: appImage).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed").resizable().aspectRatio(contentMode: .fit)
            }
        case .symbol(let name):
            Image(systemName: name).resizable().aspectRatio(contentMode: .fit)
        case .glyph(let id):
            Image(systemName: Glyph.symbolName(id)).resizable().aspectRatio(contentMode: .fit)
        }
    }
}
