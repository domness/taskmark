import LocalTodoDomain

public enum RecurrenceFormat {
    public static func fixed(_ value: String) throws -> TaskRecurrence {
        try .fixed(RecurrenceDocumentCodec.parseFixed(value))
    }

    public static func afterCompletion(_ value: String) throws -> TaskRecurrence {
        try .afterCompletion(RecurrenceDocumentCodec.parseInterval(value))
    }
}
