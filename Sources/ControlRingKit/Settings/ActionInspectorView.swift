import SwiftUI

struct ActionInspectorView: View {
    @Binding var slot: Slot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("ACTION").font(.caption).foregroundStyle(.secondary)
                if let action = actionBinding {
                    form(action)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Empty slot").foregroundStyle(.secondary)
                        Button("Add Action") { slot.action = ActionInspectorView.newAction() }
                    }
                }
            }
            .padding(16)
        }
    }

    private var actionBinding: Binding<Action>? {
        guard slot.action != nil else { return nil }
        return Binding(get: { slot.action! }, set: { slot.action = $0 })
    }

    @ViewBuilder private func form(_ action: Binding<Action>) -> some View {
        TextField("Title", text: action.title).textFieldStyle(.roundedBorder)
        TextField("Subtitle (optional)",
                  text: Binding(get: { action.wrappedValue.subtitle ?? "" },
                                set: { action.wrappedValue.subtitle = $0.isEmpty ? nil : $0 }))
            .textFieldStyle(.roundedBorder)

        Picker("Type", selection: action.type) {
            ForEach(ActionType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }

        switch action.wrappedValue.type {
        case .application:
            field("Bundle ID (e.g. com.apple.Safari)",
                  Binding(get: { action.wrappedValue.bundleID ?? "" },
                          set: { action.wrappedValue.bundleID = $0.isEmpty ? nil : $0 }))
            field("App path (used when no bundle ID)",
                  Binding(get: { action.wrappedValue.appPath ?? "" },
                          set: { action.wrappedValue.appPath = $0.isEmpty ? nil : $0 }))
            argumentsEditor(action)
        case .script:
            Text("Shell command").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: Binding(get: { action.wrappedValue.scriptCommand ?? "" },
                                     set: { action.wrappedValue.scriptCommand = $0 }))
                .frame(height: 80).font(.system(.body, design: .monospaced))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline))
        case .url:
            field("URL",
                  Binding(get: { action.wrappedValue.url ?? "" },
                          set: { action.wrappedValue.url = $0.isEmpty ? nil : $0 }))
        case .folder:
            field("Folder path",
                  Binding(get: { action.wrappedValue.folderPath ?? "" },
                          set: { action.wrappedValue.folderPath = $0.isEmpty ? nil : $0 }))
        }

        Divider()
        Text("PRESENTATION").font(.caption).foregroundStyle(.secondary)
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 4) {
                IconPicker(icon: action.presentation.icon,
                           allowAppIcon: action.wrappedValue.type == .application)
                Text("Icon").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                PaletteRow(color: action.presentation.color)
                Text("Color").font(.caption2).foregroundStyle(.secondary)
            }
        }

        Divider()
        Text("AVAILABILITY").font(.caption).foregroundStyle(.secondary)
        Picker("Shown in", selection: action.availability) {
            Text("General").tag(Availability.general)
            Text("Contextual").tag(Availability.contextual)
            Text("General + contextual").tag(Availability.generalAndContextual)
        }

        Divider()
        Button(role: .destructive) { slot.action = nil } label: { Text("Remove Action") }
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        TextField(title, text: text).textFieldStyle(.roundedBorder)
    }

    private func argumentsEditor(_ action: Binding<Action>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Arguments — one per line").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { action.wrappedValue.arguments.joined(separator: "\n") },
                set: { action.wrappedValue.arguments =
                        $0.split(separator: "\n", omittingEmptySubsequences: false)
                          .map(String.init).filter { !$0.isEmpty } }))
                .frame(height: 60)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline))
        }
    }

    static func newAction() -> Action {
        Action(title: "New Action", type: .application,
               presentation: Presentation(icon: .appIcon, color: .named("blue")))
    }
}
