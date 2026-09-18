import Yams

public struct VaultConfiguration: Codable, Equatable, Sendable {
    public let schema: Int
    public let timezone: String?
    public let preferences: [String: ConfigurationValue]

    public init(
        schema: Int = LocalTodoSchema.currentVersion,
        timezone: String? = nil,
        preferences: [String: ConfigurationValue] = [:]
    ) {
        self.schema = schema
        self.timezone = timezone
        self.preferences = preferences
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schema = try values.decode(Int.self, forKey: .schema)
        timezone = try values.decodeIfPresent(String.self, forKey: .timezone)
        preferences = try values.decodeIfPresent([String: ConfigurationValue].self, forKey: .preferences) ?? [:]
        try VaultPreferenceValidation.validate(preferences)
    }

    public static func decode(yaml: String) throws -> Self {
        try YAMLDecoder().decode(Self.self, from: yaml)
    }

    public func encoded() throws -> String {
        try YAMLEncoder().encode(self)
    }
}
