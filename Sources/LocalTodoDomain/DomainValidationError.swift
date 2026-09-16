public enum DomainValidationError: Error, Equatable, Sendable {
    case duplicateTag(String)
    case emptyTitle
    case invalidCompletionState
    case invalidChecklistItem
    case invalidSavedFilter
    case invalidCalendarDate
    case invalidRecurrenceRule
    case invalidTag(String)
    case invalidVaultPath
}
