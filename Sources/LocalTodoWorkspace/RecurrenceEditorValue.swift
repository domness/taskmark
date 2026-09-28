import LocalTodoDomain

public struct RecurrenceEditorValue: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case none = "Never"
        case fixed = "Fixed schedule"
        case afterCompletion = "After completion"
    }

    public var mode: Mode = .none
    public var frequency: FixedRecurrenceRule.Frequency = .daily
    public var interval = 1
    public var weekdays: [Weekday] = []
    public var unit: RecurrenceInterval.Unit = .day

    public init(_ recurrence: TaskRecurrence?) {
        switch recurrence {
        case let .fixed(rule):
            mode = .fixed
            frequency = rule.frequency
            interval = rule.interval
            weekdays = rule.weekdays
        case let .afterCompletion(value):
            mode = .afterCompletion
            interval = value.value
            unit = value.unit
        case nil:
            break
        }
    }

    public func recurrence() throws -> TaskRecurrence? {
        switch mode {
        case .none:
            nil
        case .fixed:
            try .fixed(FixedRecurrenceRule(
                frequency: frequency,
                interval: interval,
                weekdays: frequency == .weekly ? weekdays : []
            ))
        case .afterCompletion:
            try .afterCompletion(RecurrenceInterval(value: interval, unit: unit))
        }
    }
}
