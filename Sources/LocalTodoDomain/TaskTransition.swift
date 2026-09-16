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
        let recurrenceBase: CalendarDate = switch recurrence {
        case .fixed: baseDate
        case .afterCompletion: today
        }
        var nextDate = try recurrence.next(after: recurrenceBase, calendar: calendar)
        if case .fixed = recurrence {
            // Walk the existing cadence; completing late must not leave another overdue occurrence.
            while nextDate <= today {
                nextDate = try recurrence.next(after: nextDate, calendar: calendar)
            }
        }
        var patch = TaskPatch()
        patch.status = .set(.next)
        if task.resetChecklistOnRepeat {
            patch.body = .set(MarkdownChecklist(task.body).resetting())
        }
        if task.scheduled != nil || task.deadline == nil {
            patch.scheduled = .set(nextDate)
        }
        if let deadline = task.deadline {
            // Shift by calendar days so date separation survives DST and month-length changes.
            var gregorian = Calendar(identifier: .gregorian)
            gregorian.timeZone = calendar.timeZone
            let advance = try gregorian.dateComponents(
                [.day], from: baseDate.date(in: gregorian), to: nextDate.date(in: gregorian)
            )
            patch.deadline = try .set(deadline.adding(advance, calendar: gregorian))
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
