import LocalTodoDomain

public struct VaultDiagnostic: Equatable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case warning
        case error
    }

    public enum Kind: String, Codable, Sendable {
        case manifestMissing = "manifest_missing"
        case manifestMalformed = "manifest_malformed"
        case schemaUnsupported = "schema_unsupported"
        case timezoneInvalid = "timezone_invalid"
        case frontmatterMalformed = "frontmatter_malformed"
        case entityTypeInvalid = "entity_type_invalid"
        case requiredFieldMissing = "required_field_missing"
        case fieldInvalid = "field_invalid"
        case referenceMissing = "reference_missing"
        case referenceTypeMismatch = "reference_type_mismatch"
        case filesystemConflict = "filesystem_conflict"
        case inputOutput = "io"
    }

    public let severity: Severity
    public let kind: Kind
    public let message: String
    public let path: VaultPath?
    public let field: String?
    public let reference: VaultPath?

    public init(
        severity: Severity,
        kind: Kind,
        message: String,
        path: VaultPath? = nil,
        field: String? = nil,
        reference: VaultPath? = nil
    ) {
        self.severity = severity
        self.kind = kind
        self.message = message
        self.path = path
        self.field = field
        self.reference = reference
    }
}
