import SwiftUI

public struct RingView: View {
    @ObservedObject var viewModel: RingViewModel
    let onActivate: () -> Void

    public init(viewModel: RingViewModel, onActivate: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onActivate = onActivate
    }

    public var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.55)).background(.ultraThinMaterial, in: Circle())
            Text("Control Ring").foregroundStyle(.white).font(.headline)
        }
        .frame(width: RingView.diameter, height: RingView.diameter)
        .scaleEffect(viewModel.isOpen ? 1 : 0.85)
        .opacity(viewModel.isOpen ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: viewModel.isOpen)
    }

    static let diameter: CGFloat = 560
}
