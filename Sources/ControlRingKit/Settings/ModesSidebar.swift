import SwiftUI

struct ModesSidebar: View {
    @ObservedObject var store: ConfigStore
    @Binding var selectedModeIndex: Int
    @Binding var selectedSlotIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Modes")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)

            List(selection: listSelection) {
                ForEach(Array(store.config.modes.enumerated()), id: \.element.id) { idx, mode in
                    row(idx, mode).tag(idx)
                }
                .onMove(perform: moveModes)
            }
            .listStyle(.sidebar)

            Divider()
            HStack {
                Button { addMode() } label: { Label("Empty Mode", systemImage: "plus") }
                    .buttonStyle(.borderless)
                Spacer()
                Button(role: .destructive) { deleteSelected() } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .disabled(store.config.modes.isEmpty)
            }
            .padding(10)
        }
    }

    private var listSelection: Binding<Int?> {
        Binding(get: { selectedModeIndex },
                set: { selectedModeIndex = $0 ?? 0; selectedSlotIndex = nil })
    }

    private func row(_ idx: Int, _ mode: Mode) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Theme.color(mode.color))
                IconView(spec: mode.icon).foregroundStyle(.white).padding(5)
            }.frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(mode.name)
                if mode.contextual {
                    Text("Contextual — opens for Finder sel…")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text("\(mode.filledCount)").foregroundStyle(.secondary)
        }
    }

    private func moveModes(_ offsets: IndexSet, _ destination: Int) {
        let selectedID = store.config.modes.indices.contains(selectedModeIndex)
            ? store.config.modes[selectedModeIndex].id
            : nil
        store.config.modes.move(fromOffsets: offsets, toOffset: destination)
        if let selectedID,
           let newIndex = store.config.modes.firstIndex(where: { $0.id == selectedID }) {
            selectedModeIndex = newIndex
        } else {
            selectedModeIndex = max(0, min(selectedModeIndex, store.config.modes.count - 1))
        }
        selectedSlotIndex = nil
    }

    private func addMode() {
        store.config.modes.append(
            Mode(name: "New Mode", icon: .glyph("apps-grid"), color: .named("gray"), actions: []))
        selectedModeIndex = store.config.modes.count - 1
        selectedSlotIndex = nil
    }
    private func deleteSelected() {
        guard store.config.modes.indices.contains(selectedModeIndex) else { return }
        store.config.modes.remove(at: selectedModeIndex)
        selectedModeIndex = max(0, min(selectedModeIndex, store.config.modes.count - 1))
        selectedSlotIndex = nil
    }
}
