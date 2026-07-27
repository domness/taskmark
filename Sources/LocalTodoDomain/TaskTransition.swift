import Foundation

public enum TaskTransition {
    public static func complete(
        _ task: TodoTask,
        now: Date,
        today: CalendarDate,
        calendar: Calendar
    ) throws -> TodoTask {
        guard task.status != .canceled else {
            throw DomainValidationError.invalidCompletionState
        }
        guard let recurrence = task.recurrence else {
            var patch = TaskPatch()
            patch.status = .set(.done)
            return try patch.applying(to: task, now: now)
        }

        let baseDate = task.scheduled ?? task.deadline ?? today
        let nextDate = try recurrence.next(after: baseDate, calendar: calendar)
        var patch = TaskPatch()
        patch.status = .set(.next)
        if task.scheduled != nil || task.deadline == nil {
            patch.scheduled = .set(nextDate)
        }
        if task.deadline != nil {
            patch.deadline = .set(nextDate)
        }
        return try patch.applying(to: task, now: now)
    }

    public static func reopen(_ task: TodoTask, status: TaskStatus = .inbox, now: Date) throws -> TodoTask {
        guard task.status.isComplete, !status.isComplete else {
            throw DomainValidationError.invalidCompletionState
        }
        var patch = TaskPatch()
        patch.status = .set(status)
        return try patch.applying(to: task, now: now)
    }
}
