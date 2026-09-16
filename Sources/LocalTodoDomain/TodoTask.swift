import Foundation

public struct TodoTask: Equatable, Sendable {
    public let path: VaultPath
    public let title: String
    public let status: TaskStatus
    public let priority: TaskPriority?
    public let scheduled: CalendarDate?
    public let deadline: CalendarDate?
    public let project: VaultPath?
    public let area: VaultPath?
    public let tags: [String]
    public let recurrence: TaskRecurrence?
    public let resetChecklistOnRepeat: Bool
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?

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
        recurrence: TaskRecurrence? = nil,
        resetChecklistOnRepeat: Bool = false,
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
        self.priority = priority
        self.scheduled = scheduled
        self.deadline = deadline
        self.project = project
        self.area = area
        self.tags = tags
        self.recurrence = recurrence
        self.resetChecklistOnRepeat = resetChecklistOnRepeat
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}
