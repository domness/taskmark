public struct VaultRecord<Value: Equatable & Sendable>: Equatable, Sendable {
    public let value: Value
    public let revision: FileRevision

    public init(value: Value, revision: FileRevision) {
        self.value = value
        self.revision = revision
    }
}
