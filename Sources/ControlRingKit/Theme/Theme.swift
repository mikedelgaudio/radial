import SwiftUI

public enum Theme {
    /// Canonical palette. `ColorSpec.named(key)` resolves here; unknown => amber.
    public static let palette: [String: Color] = [
        "amber":  Color(red: 1.00, green: 0.72, blue: 0.20),
        "red":    Color(red: 0.98, green: 0.28, blue: 0.29),
        "orange": Color(red: 1.00, green: 0.58, blue: 0.20),
        "yellow": Color(red: 1.00, green: 0.82, blue: 0.28),
        "green":  Color(red: 0.30, green: 0.78, blue: 0.42),
        "teal":   Color(red: 0.25, green: 0.78, blue: 0.78),
        "blue":   Color(red: 0.25, green: 0.55, blue: 0.98),
        "indigo": Color(red: 0.42, green: 0.42, blue: 0.90),
        "purple": Color(red: 0.66, green: 0.40, blue: 0.92),
        "pink":   Color(red: 0.96, green: 0.38, blue: 0.62),
        "brown":  Color(red: 0.66, green: 0.51, blue: 0.38),
        "gray":   Color(red: 0.60, green: 0.62, blue: 0.66),
    ]
    public static let paletteOrder = ["amber","red","orange","yellow","green","teal",
                                      "blue","indigo","purple","pink","brown","gray"]

    public static func color(_ spec: ColorSpec) -> Color {
        switch spec {
        case .named(let n): return palette[n] ?? palette["amber"]!
        case .rgba(let r, let g, let b, let a):
            return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        }
    }

    /// Base amber accent. The ring tints selection/glow by the ACTIVE MODE's color;
    /// resolve that with `accent(for:)` (falls back to amber).
    public static let accent = palette["amber"]!
    public static func accent(for mode: Mode?) -> Color {
        guard let mode else { return accent }
        return color(mode.color)
    }

    /// Appearance-aware ring plate: dark glass in dark mode, light glass in light mode.
    public static func ringPlate(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.55) : Color.white.opacity(0.62)
    }
    /// Neutral surfaces that read acceptably in both appearances.
    public static let slotPlate = Color.gray.opacity(0.16)
    public static let hairline = Color.gray.opacity(0.28)
}
