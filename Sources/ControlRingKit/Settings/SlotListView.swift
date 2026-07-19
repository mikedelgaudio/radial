import SwiftUI

struct SlotListView: View {
    @Binding var mode: Mode
    @Binding var selectedSlotIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("OUTER RING SLOTS")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
            List(selection: $selectedSlotIndex) {
                ForEach(mode.slots) { slot in
                    row(slot).tag(slot.index)
                }
                .onMove(perform: moveSlots)
            }
        }
    }

    /// Reorder actions across the fixed 8 slots, keeping indices 0..7 stable.
    private func moveSlots(_ offsets: IndexSet, _ destination: Int) {
        var actions = mode.slots.map { $0.action }
        actions.move(fromOffsets: offsets, toOffset: destination)
        mode.slots = actions.enumerated().map { Slot(index: $0.offset, action: $0.element) }
        selectedSlotIndex = nil
    }

    private func row(_ slot: Slot) -> some View {
        HStack(spacing: 10) {
            Text("\(slot.index)").foregroundStyle(.secondary).frame(width: 16)
            if let action = slot.action {
                SlotTile(action: action, selected: false, size: 24)
                Text(action.title)
                Spacer()
                Text(action.type.rawValue.capitalized).foregroundStyle(.secondary)
            } else {
                Image(systemName: "square.dashed").foregroundStyle(.secondary)
                Text("Empty slot").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}
