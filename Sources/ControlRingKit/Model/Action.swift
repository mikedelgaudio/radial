import Foundation

public struct Presentation: Codable, Equatable, Hashable {
    public var icon: IconSpec
    public var color: ColorSpec
    public init(icon: IconSpec, color: ColorSpec) {
        self.icon = icon
        self.color = color
    }
}

public struct Action: Codable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var subtitle: String?
    public var type: ActionType
    public var bundleID: String?
    public var appPath: String?
    public var arguments: [String]
    public var scriptCommand: String?
    public var url: String?
    public var folderPath: String?
    public var presentation: Presentation
    public var availability: Availability

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        type: ActionType,
        bundleID: String? = nil,
        appPath: String? = nil,
        arguments: [String] = [],
        scriptCommand: String? = nil,
        url: String? = nil,
        folderPath: String? = nil,
        presentation: Presentation,
        availability: Availability = .general
    ) {
        self.id = id; self.title = title; self.subtitle = subtitle
        self.type = type; self.bundleID = bundleID; self.appPath = appPath
        self.arguments = arguments; self.scriptCommand = scriptCommand
        self.url = url; self.folderPath = folderPath
        self.presentation = presentation; self.availability = availability
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type, bundleID, appPath, arguments
        case scriptCommand, url, folderPath, presentation, availability
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        type = try c.decode(ActionType.self, forKey: .type)
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID)
        appPath = try c.decodeIfPresent(String.self, forKey: .appPath)
        arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        scriptCommand = try c.decodeIfPresent(String.self, forKey: .scriptCommand)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        folderPath = try c.decodeIfPresent(String.self, forKey: .folderPath)
        presentation = try c.decode(Presentation.self, forKey: .presentation)
        availability = try c.decodeIfPresent(Availability.self, forKey: .availability) ?? .general
    }
}
