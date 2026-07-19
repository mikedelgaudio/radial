import SwiftUI

struct ModeEditorView: View {
    @Binding var mode: Mode
    var onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODE").font(.caption).foregroundStyle(.secondary)
            TextField("Mode name", text: $mode.name).textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    IconPicker(icon: $mode.icon, allowAppIcon: false)
                    Text("Icon").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    PaletteRow(color: $mode.color)
                    Text("Color").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Toggle("Contextual mode (auto-opens for Finder selections)", isOn: $mode.contextual)
                .toggleStyle(.checkbox)

            Button("Clear Mode", action: onClear)
        }
    }
}
