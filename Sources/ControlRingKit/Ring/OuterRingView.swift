import SwiftUI

struct OuterRingView: View {
    @ObservedObject var viewModel: RingViewModel
    let center: CGPoint
    let radius: CGFloat
    let slotSize: CGFloat
    let accent: Color
    let onActivate: () -> Void

    var body: some View {
        let geo = RingGeometry(slotCount: Mode.slotCount, center: center, radius: radius)
        ForEach(0..<Mode.slotCount, id: \.self) { i in
            SlotTile(action: viewModel.currentMode?.slots[safe: i]?.action,
                     selected: viewModel.focus == .outer && viewModel.outerIndex == i,
                     size: slotSize, accent: accent)
                .position(geo.position(for: i))
                .allowsHitTesting(false)
        }
    }
}
