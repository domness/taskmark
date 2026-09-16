import Foundation

public extension TaskTransition {
    static func reschedule(
        _ task: TodoTask, to date: CalendarDate, now: Date, calendar: Calendar
    ) throws -> TodoTask {
        guard !task.status.isComplete else { throw DomainValidationError.invalidCompletionState }
        let anchor = task.scheduled ?? task.deadline
        guard anchor != date else { return task }
        var patch = TaskPatch()
        if task.scheduled != nil || task.deadline == nil {
            patch.scheduled = .set(date)
        }
        if let deadline = task.deadline, let anchor {
            var gregorian = Calendar(identifier: .gregorian)
            gregorian.timeZone = calendar.timeZone
            let shift = try gregorian.dateComponents(
                [.day],
                from: anchor.date(in: gregorian),
                to: date.date(in: gregorian)
            )
            patch.deadline = try .set(deadline.adding(shift, calendar: gregorian))
        }
        return try patch.applying(to: task, now: now)
    }
}
