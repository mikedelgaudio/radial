import SwiftUI

struct CenterHubView: View {
    @ObservedObject var viewModel: RingViewModel
    let radius: CGFloat
    let accent: Color
    let onActivate: () -> Void

    var body: some View {
        let selected = viewModel.focus == .center
        let mode = viewModel.currentMode
        ZStack {
            Circle().fill(
                RadialGradient(colors: [accent.opacity(0.35), .clear],
                               center: .center, startRadius: 2, endRadius: radius))
            Circle().stroke(accent.opacity(selected ? 0.9 : 0.5),
                            lineWidth: selected ? 3 : 1.5)
            IconView(spec: mode?.icon ?? .glyph("apps-grid"))
                .foregroundStyle(accent)
                .frame(width: radius * 0.8, height: radius * 0.8)
        }
        .frame(width: radius * 2, height: radius * 2)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
    }
}
