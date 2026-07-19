import SwiftUI
import AppKit

public struct PaletteRow: View {
    @Binding var color: ColorSpec
    public init(color: Binding<ColorSpec>) { self._color = color }
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Theme.paletteOrder, id: \.self) { key in
                Circle()
                    .fill(Theme.color(.named(key)))
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.primary, lineWidth: isSelected(key) ? 2 : 0))
                    .onTapGesture { color = .named(key) }
            }
            // Custom color (writes ColorSpec.rgba)
            ColorPicker("", selection: customBinding, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 22, height: 22)
        }
    }
    private func isSelected(_ k: String) -> Bool {
        if case .named(let n) = color { return n == k }
        return false
    }
    private var customBinding: Binding<Color> {
        Binding(get: { Theme.color(color) }, set: { color = ColorSpec.from($0) })
    }
}

extension ColorSpec {
    /// Bridges a SwiftUI Color into an sRGB `.rgba` ColorSpec.
    static func from(_ color: Color) -> ColorSpec {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        return .rgba(Double(ns.redComponent), Double(ns.greenComponent),
                     Double(ns.blueComponent), Double(ns.alphaComponent))
    }
}

public struct IconPicker: View {
    @Binding var icon: IconSpec
    let allowAppIcon: Bool
    private let symbols = ["safari","globe","envelope.fill","music.note","terminal.fill",
        "folder.fill","gearshape.fill","chevron.left.forwardslash.chevron.right","star.fill",
        "bolt.fill","calendar","map.fill","network","moon.fill","lock.fill","play.rectangle.fill",
        "square.grid.2x2.fill"]
    public init(icon: Binding<IconSpec>, allowAppIcon: Bool) {
        self._icon = icon; self.allowAppIcon = allowAppIcon
    }
    public var body: some View {
        Menu {
            if allowAppIcon { Button("App Icon") { icon = .appIcon } }
            ForEach(symbols, id: \.self) { s in
                Button { icon = .symbol(s) } label: { Label(s, systemImage: s) }
            }
        } label: {
            IconView(spec: icon)
                .frame(width: 26, height: 26)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.slotPlate))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
