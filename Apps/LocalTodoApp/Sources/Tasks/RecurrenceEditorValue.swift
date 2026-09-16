import LocalTodoDomain

struct RecurrenceEditorValue {
    enum Mode: String, CaseIterable {
        case none = "Never"
        case fixed = "Fixed schedule"
        case afterCompletion = "After completion"
    }

    var mode: Mode = .none
    var frequency: FixedRecurrenceRule.Frequency = .daily
    var interval = 1
    var weekdays: [Weekday] = []
    var unit: RecurrenceInterval.Unit = .day

    init(_ recurrence: TaskRecurrence?) {
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
        case nil: break
        }
    }

    func recurrence() throws -> TaskRecurrence? {
        switch mode {
        case .none: nil
        case .fixed:
            try .fixed(FixedRecurrenceRule(
                frequency: frequency, interval: interval, weekdays: frequency == .weekly ? weekdays : []
            ))
        case .afterCompletion:
            try .afterCompletion(RecurrenceInterval(value: interval, unit: unit))
        }
    }
}
