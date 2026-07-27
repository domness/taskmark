import LocalTodoDomain

public enum EntityDocumentError: Error, Equatable, Sendable {
    case invalidDomainValue(DomainValidationError)
    case invalidField(String)
    case missingField(String)
    case unsupportedEntityType(String)
}
