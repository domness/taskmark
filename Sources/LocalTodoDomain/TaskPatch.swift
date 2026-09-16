import Foundation

public struct TaskPatch: Equatable, Sendable {
    public var title: FieldUpdate<String> = .unchanged
    public var status: FieldUpdate<TaskStatus> = .unchanged
    public var priority: FieldUpdate<TaskPriority?> = .unchanged
    public var scheduled: FieldUpdate<CalendarDate?> = .unchanged
    public var deadline: FieldUpdate<CalendarDate?> = .unchanged
    public var project: FieldUpdate<VaultPath?> = .unchanged
    public var area: FieldUpdate<VaultPath?> = .unchanged
    public var tags: FieldUpdate<[String]> = .unchanged
    public var recurrence: FieldUpdate<TaskRecurrence?> = .unchanged
    public var resetChecklistOnRepeat: FieldUpdate<Bool> = .unchanged
    public var body: FieldUpdate<String> = .unchanged

    public init() {}

    public func applying(to task: TodoTask, now: Date) throws -> TodoTask {
        let nextStatus = status.resolve(task.status)
        let nextCompletedAt: Date? = if nextStatus == .done {
            task.completedAt ?? now
        } else {
            nil
        }

        return try TodoTask(
            path: task.path,
            title: title.resolve(task.title),
            status: nextStatus,
            priority: priority.resolve(task.priority),
            scheduled: scheduled.resolve(task.scheduled),
            deadline: deadline.resolve(task.deadline),
            project: project.resolve(task.project),
            area: area.resolve(task.area),
            tags: tags.resolve(task.tags),
            recurrence: recurrence.resolve(task.recurrence),
            resetChecklistOnRepeat: resetChecklistOnRepeat.resolve(task.resetChecklistOnRepeat),
            body: body.resolve(task.body),
            createdAt: task.createdAt,
            updatedAt: now,
            completedAt: nextCompletedAt
        )
    }
}
