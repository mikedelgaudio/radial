import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    @State private var selectedModeIndex = 0
    @State private var selectedSlotIndex: Int? = nil
    @State private var debouncer = Debouncer()

    public init(store: ConfigStore) { self.store = store }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ModesSidebar(store: store,
                             selectedModeIndex: $selectedModeIndex,
                             selectedSlotIndex: $selectedSlotIndex)
                    .frame(width: 232)
                Divider()
                middleColumn.frame(minWidth: 380, maxWidth: .infinity)
                Divider()
                inspectorColumn.frame(width: 320)
            }
            Divider()
            SettingsBottomBar(store: store)
        }
        .frame(minWidth: 960, minHeight: 620)
        .onChange(of: store.config) { _ in debouncer.call { store.save() } }
        .onAppear(perform: clampSelection)
    }

    @ViewBuilder private var middleColumn: some View {
        if store.config.modes.indices.contains(selectedModeIndex) {
            VStack(spacing: 0) {
                ModeEditorView(mode: modeBinding(selectedModeIndex)) { clearMode(selectedModeIndex) }
                    .padding(16)
                Divider()
                SlotListView(mode: modeBinding(selectedModeIndex),
                             selectedSlotIndex: $selectedSlotIndex)
            }
        } else { placeholder("No mode selected") }
    }

    @ViewBuilder private var inspectorColumn: some View {
        if let si = selectedSlotIndex,
           store.config.modes.indices.contains(selectedModeIndex),
           store.config.modes[selectedModeIndex].slots.indices.contains(si) {
            ActionInspectorView(slot: slotBinding(selectedModeIndex, si))
        } else { placeholder("Select a slot to edit its action") }
    }

    private func placeholder(_ text: String) -> some View {
        VStack { Spacer(); Text(text).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modeBinding(_ i: Int) -> Binding<Mode> {
        Binding(get: { store.config.modes[i] }, set: { store.config.modes[i] = $0 })
    }
    private func slotBinding(_ m: Int, _ s: Int) -> Binding<Slot> {
        Binding(get: { store.config.modes[m].slots[s] },
                set: { store.config.modes[m].slots[s] = $0 })
    }
    private func clearMode(_ i: Int) {
        for s in store.config.modes[i].slots.indices { store.config.modes[i].slots[s].action = nil }
    }
    private func clampSelection() {
        if store.config.modes.isEmpty { selectedModeIndex = 0 }
        else { selectedModeIndex = min(max(0, selectedModeIndex), store.config.modes.count - 1) }
    }
}
