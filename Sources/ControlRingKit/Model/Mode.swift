import Foundation

public struct Slot: Codable, Equatable, Identifiable, Hashable {
    public var index: Int
    public var action: Action?
    public var id: Int { index }
    public init(index: Int, action: Action? = nil) {
        self.index = index; self.action = action
    }
}

public struct Mode: Codable, Equatable, Identifiable, Hashable {
    public static let slotCount = 8

    public var id: UUID
    public var name: String
    public var icon: IconSpec
    public var color: ColorSpec
    public var contextual: Bool
    public var slots: [Slot]

    /// Designated init that normalizes to exactly `slotCount` slots.
    public init(id: UUID = UUID(), name: String, icon: IconSpec, color: ColorSpec,
                contextual: Bool = false, slots: [Slot]) {
        self.id = id; self.name = name; self.icon = icon
        self.color = color; self.contextual = contextual
        self.slots = Mode.normalized(slots)
    }

    /// Convenience: build from an ordered list of optional actions.
    public init(id: UUID = UUID(), name: String, icon: IconSpec, color: ColorSpec,
                contextual: Bool = false, actions: [Action?]) {
        let slots = actions.enumerated().map { Slot(index: $0.offset, action: $0.element) }
        self.init(id: id, name: name, icon: icon, color: color,
                  contextual: contextual, slots: slots)
    }

    public var filledCount: Int { slots.filter { $0.action != nil }.count }

    public static func normalized(_ input: [Slot]) -> [Slot] {
        (0..<slotCount).map { i in
            Slot(index: i, action: input.first(where: { $0.index == i })?.action)
        }
    }

    private enum CodingKeys: String, CodingKey { case id, name, icon, color, contextual, slots }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(IconSpec.self, forKey: .icon)
        color = try c.decode(ColorSpec.self, forKey: .color)
        contextual = try c.decodeIfPresent(Bool.self, forKey: .contextual) ?? false
        let raw = try c.decodeIfPresent([Slot].self, forKey: .slots) ?? []
        slots = Mode.normalized(raw)
    }
}

public struct Settings: Codable, Equatable, Hashable {
    public var showInMenuBar: Bool
    public var ringDiameter: Double?
    public var ringOriginX: Double?
    public var ringOriginY: Double?

    public init(showInMenuBar: Bool = true,
                ringDiameter: Double? = nil,
                ringOriginX: Double? = nil,
                ringOriginY: Double? = nil) {
        self.showInMenuBar = showInMenuBar
        self.ringDiameter = ringDiameter
        self.ringOriginX = ringOriginX
        self.ringOriginY = ringOriginY
    }

    private enum CodingKeys: String, CodingKey {
        case showInMenuBar, ringDiameter, ringOriginX, ringOriginY
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        ringDiameter = try c.decodeIfPresent(Double.self, forKey: .ringDiameter)
        ringOriginX = try c.decodeIfPresent(Double.self, forKey: .ringOriginX)
        ringOriginY = try c.decodeIfPresent(Double.self, forKey: .ringOriginY)
    }
}

public struct Config: Codable, Equatable, Hashable {
    public var version: Int
    public var hotkey: HotKeySpec
    public var modes: [Mode]
    public var settings: Settings

    public init(version: Int = ControlRingKit.schemaVersion,
                hotkey: HotKeySpec = .default,
                modes: [Mode], settings: Settings = Settings()) {
        self.version = version; self.hotkey = hotkey
        self.modes = modes; self.settings = settings
    }

    private enum CodingKeys: String, CodingKey { case version, hotkey, modes, settings }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? ControlRingKit.schemaVersion
        hotkey = try c.decodeIfPresent(HotKeySpec.self, forKey: .hotkey) ?? .default
        modes = try c.decodeIfPresent([Mode].self, forKey: .modes) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
    }
}
