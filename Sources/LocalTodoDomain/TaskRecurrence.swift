import Foundation

public enum TaskRecurrence: Equatable, Sendable {
    case fixed(FixedRecurrenceRule)
    case afterCompletion(RecurrenceInterval)

    public func next(after date: CalendarDate, calendar: Calendar) throws -> CalendarDate {
        switch self {
        case let .fixed(rule):
            try rule.next(after: date, calendar: calendar)
        case let .afterCompletion(interval):
            try date.adding(interval.dateComponents(), calendar: calendar)
        }
    }
}
