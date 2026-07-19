import SwiftUI

struct SettingsBottomBar: View {
    @ObservedObject var store: ConfigStore
    @State private var confirmingRestore = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
            Text("\(store.config.hotkey.displayString)  summons the ring")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reveal Config") { store.revealInFinder() }
            Button("Restore Defaults") { confirmingRestore = true }
        }
        .padding(12)
        .confirmationDialog("Restore default configuration?",
                            isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Restore Defaults", role: .destructive) { store.restoreDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This overwrites your current modes and slots.")
        }
    }
}
