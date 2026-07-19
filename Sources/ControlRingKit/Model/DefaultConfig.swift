import Foundation

public enum DefaultConfig {
    public static func make() -> Config {
        Config(hotkey: .default, modes: [appsMode(), webMode(), devMode(), systemMode()])
    }

    private static func app(_ title: String, _ bundleID: String, _ color: String) -> Action {
        Action(title: title, type: .application, bundleID: bundleID,
               presentation: Presentation(icon: .appIcon, color: .named(color)))
    }
    private static func urlAction(_ title: String, _ url: String, _ symbol: String, _ color: String) -> Action {
        Action(title: title, type: .url, url: url,
               presentation: Presentation(icon: .symbol(symbol), color: .named(color)))
    }
    private static func script(_ title: String, _ cmd: String, _ symbol: String, _ color: String) -> Action {
        Action(title: title, type: .script, arguments: [], scriptCommand: cmd,
               presentation: Presentation(icon: .symbol(symbol), color: .named(color)))
    }

    private static func appsMode() -> Mode {
        Mode(name: "Apps", icon: .glyph("apps-grid"), color: .named("amber"), actions: [
            app("Safari", "com.apple.Safari", "blue"),
            app("Notes", "com.apple.Notes", "yellow"),
            nil,
            app("Mail", "com.apple.mail", "pink"),
            app("Music", "com.apple.Music", "red"),
            nil,
            app("Terminal", "com.apple.Terminal", "green"),
            nil,
        ])
    }
    private static func webMode() -> Mode {
        Mode(name: "Web", icon: .symbol("globe"), color: .named("blue"), actions: [
            urlAction("GitHub", "https://github.com", "chevron.left.forwardslash.chevron.right", "gray"),
            urlAction("Gmail", "https://mail.google.com", "envelope.fill", "red"),
            urlAction("Calendar", "https://calendar.google.com", "calendar", "blue"),
            urlAction("YouTube", "https://youtube.com", "play.rectangle.fill", "red"),
            urlAction("Maps", "https://maps.google.com", "map.fill", "green"),
            nil, nil, nil,
        ])
    }
    private static func devMode() -> Mode {
        Mode(name: "Dev", icon: .symbol("chevron.left.forwardslash.chevron.right"),
             color: .named("green"), actions: [
            app("Xcode", "com.apple.dt.Xcode", "blue"),
            app("Terminal", "com.apple.Terminal", "green"),
            script("Localhost", "open http://localhost:3000", "network", "teal"),
            script("Flush DNS", "sudo dscacheutil -flushcache", "arrow.clockwise", "orange"),
            nil, nil, nil, nil,
        ])
    }
    private static func systemMode() -> Mode {
        Mode(name: "System", icon: .symbol("gearshape.fill"), color: .named("gray"), actions: [
            app("System Settings", "com.apple.systempreferences", "gray"),
            script("Sleep", "pmset sleepnow", "moon.fill", "indigo"),
            script("Lock Screen", "pmset displaysleepnow", "lock.fill", "blue"),
            nil, nil, nil, nil, nil,
        ])
    }
}
