import Foundation

public struct TodoTask: Equatable, Sendable {
    public let path: VaultPath
    public var title: String
    public var status: TaskStatus
    public var priority: TaskPriority?
    public var scheduled: CalendarDate?
    public var deadline: CalendarDate?
    public var project: VaultPath?
    public var area: VaultPath?
    public var tags: [String]
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public init(
        path: VaultPath,
        title: String,
        status: TaskStatus,
        priority: TaskPriority? = nil,
        scheduled: CalendarDate? = nil,
        deadline: CalendarDate? = nil,
        project: VaultPath? = nil,
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

        self.path = path
        self.title = normalizedTitle
        self.status = status
        self.priority = priority
        self.scheduled = scheduled
        self.deadline = deadline
        self.project = project
        self.area = area
        self.tags = tags
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}
