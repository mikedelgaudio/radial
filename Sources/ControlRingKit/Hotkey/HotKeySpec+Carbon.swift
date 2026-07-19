import Carbon.HIToolbox

public extension HotKeySpec {
    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        for m in modifiers {
            switch m {
            case "command": flags |= UInt32(cmdKey)
            case "option":  flags |= UInt32(optionKey)
            case "shift":   flags |= UInt32(shiftKey)
            case "control": flags |= UInt32(controlKey)
            default: break
            }
        }
        return flags
    }

    var displayString: String {
        // Order matches the app's convention/screenshot: ⌘⌥⇧⌃ then key.
        var s = ""
        if modifiers.contains("command") { s += "⌘" }
        if modifiers.contains("option")  { s += "⌥" }
        if modifiers.contains("shift")   { s += "⇧" }
        if modifiers.contains("control") { s += "⌃" }
        s += HotKeySpec.keyLabel(for: keyCode)
        return s
    }

    static func keyLabel(for keyCode: Int) -> String {
        switch keyCode {
        case 33: return "["
        case 30: return "]"
        case 49: return "Space"
        default: return "#\(keyCode)"
        }
    }
}
