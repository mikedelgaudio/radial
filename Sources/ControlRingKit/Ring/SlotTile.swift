import SwiftUI

public struct SlotTile: View {
    let action: Action?
    let selected: Bool
    var size: CGFloat = 58
    var accent: Color = Theme.accent

    public init(action: Action?, selected: Bool, size: CGFloat = 58, accent: Color = Theme.accent) {
        self.action = action; self.selected = selected; self.size = size; self.accent = accent
    }

    public var body: some View {
        ZStack {
            if let action { filled(action) } else { empty }
        }
        .frame(width: size, height: size)
        .scaleEffect(selected ? 1.15 : 1.0)
        .shadow(color: selected ? accent.opacity(0.55) : .clear,
                radius: selected ? 14 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.29)
                .stroke(accent, lineWidth: selected ? 2.5 : 0)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
    }

    @ViewBuilder private func filled(_ action: Action) -> some View {
        if case .appIcon = action.presentation.icon,
           let image = AppIconResolver.appImage(for: action) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            RoundedRectangle(cornerRadius: size * 0.29)
                .fill(Theme.color(action.presentation.color).gradient)
            IconView(spec: action.presentation.icon)
                .foregroundStyle(.white)
                .padding(size * 0.24)
        }
    }

    private var empty: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(.secondary.opacity(0.55))
            Image(systemName: "plus").foregroundStyle(.secondary)
                .font(.system(size: size * 0.34, weight: .semibold))
        }
    }
}
