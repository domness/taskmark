import Yams

public struct VaultConfiguration: Codable, Equatable, Sendable {
    public let schema: Int
    public let timezone: String?

    public init(schema: Int = LocalTodoSchema.currentVersion, timezone: String? = nil) {
        self.schema = schema
        self.timezone = timezone
    }

    public static func decode(yaml: String) throws -> Self {
        try YAMLDecoder().decode(Self.self, from: yaml)
    }

    public func encoded() throws -> String {
        try YAMLEncoder().encode(self)
    }
}
