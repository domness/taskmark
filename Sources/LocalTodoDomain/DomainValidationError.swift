public enum DomainValidationError: Error, Equatable, Sendable {
    case emptyTitle
    case invalidCalendarDate
    case invalidVaultPath
}
