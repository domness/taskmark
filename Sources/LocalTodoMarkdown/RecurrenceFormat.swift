import LocalTodoDomain

public enum RecurrenceFormat {
    public static func expression(_ recurrence: TaskRecurrence) -> String {
        switch recurrence {
        case let .fixed(rule): RecurrenceDocumentCodec.format(rule)
        case let .afterCompletion(interval): "P\(interval.value)\(interval.unit.rawValue)"
        }
    }

    public static func fixed(_ value: String) throws -> TaskRecurrence {
        try .fixed(RecurrenceDocumentCodec.parseFixed(value))
    }

    public static func afterCompletion(_ value: String) throws -> TaskRecurrence {
        try .afterCompletion(RecurrenceDocumentCodec.parseInterval(value))
    }
}
