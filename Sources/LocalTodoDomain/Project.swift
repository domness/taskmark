import Foundation

public struct Project: Equatable, Sendable {
    public let path: VaultPath
    public let title: String
    public let status: ProjectStatus
    public let area: VaultPath?
    public let tags: [String]
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?

    public init(
        path: VaultPath,
        title: String,
        status: ProjectStatus,
        area: VaultPath? = nil,
        tags: [String] = [],
        body: String = "",
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date? = nil
    ) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw DomainValidationError.emptyTitle
        }
        try TagValidation.validate(tags)

        let isCompletionValid = status == .done ? completedAt != nil : completedAt == nil
        guard isCompletionValid else {
            throw DomainValidationError.invalidCompletionState
        }

        self.path = path
        self.title = normalizedTitle
        self.status = status
        self.area = area
        self.tags = tags
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}
