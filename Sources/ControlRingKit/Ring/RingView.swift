import SwiftUI

public struct RingView: View {
    @ObservedObject var viewModel: RingViewModel
    @Environment(\.colorScheme) private var scheme
    let onActivate: () -> Void

    public init(viewModel: RingViewModel, onActivate: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onActivate = onActivate
    }

    public static let diameter: CGFloat = 560
    private static let center = CGPoint(x: diameter / 2, y: diameter / 2)
    private static let bezelRadius: CGFloat = 268
    private static let outerRadius: CGFloat = 210
    private static let innerRadius: CGFloat = 120
    private static let centerHubRadius: CGFloat = 62

    public var body: some View {
        let accent = Theme.accent(for: viewModel.currentMode)
        ZStack {
            Circle()
                .fill(Theme.ringPlate(scheme))
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: Self.bezelRadius * 2, height: Self.bezelRadius * 2)

            RingBezelCanvas(bezelRadius: Self.bezelRadius,
                            innerGlowRadius: Self.innerRadius + 42, accent: accent)
            OuterRingView(viewModel: viewModel, center: Self.center,
                          radius: Self.outerRadius, accent: accent, onActivate: onActivate)
            ModeRingView(viewModel: viewModel, center: Self.center,
                         radius: Self.innerRadius, accent: accent, onActivate: onActivate)
            CenterHubView(viewModel: viewModel, radius: Self.centerHubRadius,
                          accent: accent, onActivate: onActivate)
                .position(Self.center)

            if let msg = viewModel.transientMessage {
                Text(msg)
                    .font(.callout).foregroundStyle(.white).lineLimit(2)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.85)))
                    .frame(maxWidth: Self.diameter * 0.7)
                    .position(x: Self.center.x, y: Self.diameter - 64)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.transientMessage)
        .frame(width: Self.diameter, height: Self.diameter)
        .scaleEffect(viewModel.isOpen ? 1 : 0.86)
        .opacity(viewModel.isOpen ? 1 : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: viewModel.isOpen)
    }
}
