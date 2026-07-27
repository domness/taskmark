import Foundation

public struct Area: Equatable, Sendable {
    public let path: VaultPath
    public let title: String
    public let status: AreaStatus
    public let tags: [String]
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        path: VaultPath,
        title: String,
        status: AreaStatus,
        tags: [String] = [],
        body: String = "",
        createdAt: Date,
        updatedAt: Date
    ) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw DomainValidationError.emptyTitle
        }
        try TagValidation.validate(tags)

        self.path = path
        self.title = normalizedTitle
        self.status = status
        self.tags = tags
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
