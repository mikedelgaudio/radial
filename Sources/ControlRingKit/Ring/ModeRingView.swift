import SwiftUI

struct ModeRingView: View {
    @ObservedObject var viewModel: RingViewModel
    let center: CGPoint
    let radius: CGFloat
    let chipSize: CGFloat
    let accent: Color
    let onActivate: () -> Void

    var body: some View {
        let count = viewModel.innerItemCount
        let geo = RingGeometry(slotCount: count, center: center, radius: radius)
        ForEach(0..<count, id: \.self) { i in
            chip(for: i)
                .position(geo.position(for: i))
                .onHover { if $0 { viewModel.focus = .inner; viewModel.innerIndex = i } }
                .onTapGesture {
                    viewModel.focus = .inner; viewModel.innerIndex = i; onActivate()
                }
        }
    }

    @ViewBuilder private func chip(for i: Int) -> some View {
        let isSettings = i == viewModel.settingsInnerIndex
        let isAddMode = i == viewModel.addModeInnerIndex
        let selected = viewModel.focus == .inner && viewModel.innerIndex == i
        let current = !isSettings && !isAddMode && viewModel.currentModeIndex == i

        Group {
            if isAddMode {
                ZStack {
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Image(systemName: "plus").foregroundStyle(.secondary)
                }
            } else {
                let icon: IconSpec = isSettings ? .glyph("gear") : viewModel.modes[i].icon
                let tint: Color = isSettings ? Theme.color(.named("gray"))
                                             : Theme.color(viewModel.modes[i].color)
                ZStack {
                    Circle().fill(current ? tint.opacity(0.28) : Color.gray.opacity(0.12))
                    IconView(spec: icon)
                        .foregroundStyle(current ? tint : .primary.opacity(0.8))
                        .padding(chipSize * 0.25)
                }
            }
        }
        .frame(width: chipSize, height: chipSize)
        .overlay(Circle().stroke(accent, lineWidth: selected ? 2 : 0))
        .shadow(color: selected ? accent.opacity(0.5) : .clear, radius: selected ? 10 : 0)
        .scaleEffect(selected ? 1.18 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
    }
}
