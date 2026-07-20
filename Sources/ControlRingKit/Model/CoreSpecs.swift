import Foundation

public enum ActionType: String, Codable, Equatable, CaseIterable, Hashable {
    case application, script, url, folder
}

public enum Availability: String, Codable, Equatable, CaseIterable, Hashable {
    case general, contextual, generalAndContextual
}

public enum IconSpec: Codable, Equatable, Hashable {
    case appIcon
    case symbol(String)   // SF Symbol name
    case glyph(String)    // built-in glyph id

    private enum Kind: String, Codable { case appIcon, symbol, glyph }
    private enum CodingKeys: String, CodingKey { case kind, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .appIcon: self = .appIcon
        case .symbol:  self = .symbol(try c.decode(String.self, forKey: .value))
        case .glyph:   self = .glyph(try c.decode(String.self, forKey: .value))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .appIcon: try c.encode(Kind.appIcon, forKey: .kind)
        case .symbol(let s): try c.encode(Kind.symbol, forKey: .kind); try c.encode(s, forKey: .value)
        case .glyph(let g):  try c.encode(Kind.glyph, forKey: .kind); try c.encode(g, forKey: .value)
        }
    }
}

public enum ColorSpec: Codable, Equatable, Hashable {
    case named(String)                          // palette key (see Theme.palette)
    case rgba(Double, Double, Double, Double)

    private enum Kind: String, Codable { case named, rgba }
    private enum CodingKeys: String, CodingKey { case kind, name, r, g, b, a }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .named:
            self = .named(try c.decode(String.self, forKey: .name))
        case .rgba:
            self = .rgba(try c.decode(Double.self, forKey: .r),
                         try c.decode(Double.self, forKey: .g),
                         try c.decode(Double.self, forKey: .b),
                         try c.decode(Double.self, forKey: .a))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .named(let n):
            try c.encode(Kind.named, forKey: .kind); try c.encode(n, forKey: .name)
        case .rgba(let r, let g, let b, let a):
            try c.encode(Kind.rgba, forKey: .kind)
            try c.encode(r, forKey: .r); try c.encode(g, forKey: .g)
            try c.encode(b, forKey: .b); try c.encode(a, forKey: .a)
        }
    }
}

public struct HotKeySpec: Codable, Equatable, Hashable {
    public var keyCode: Int
    public var modifiers: [String]   // "command","option","shift","control"

    public init(keyCode: Int, modifiers: [String]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    /// Default summon hotkey: ⌥Space (Option+Space). kVK_Space = 49.
    public static let `default` = HotKeySpec(
        keyCode: 49, modifiers: ["option"]
    )

    /// The original v1 default (⌘⌥⇧[); used to migrate existing configs.
    public static let legacyDefault = HotKeySpec(
        keyCode: 33, modifiers: ["command", "option", "shift"]
    )
}
