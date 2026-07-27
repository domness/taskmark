import LocalTodoDomain

public enum VaultStoreError: Error, Equatable, Sendable {
    case conflict(VaultPath)
    case destinationExists(VaultPath)
    case invalidVault(String)
    case missingReference(VaultPath)
    case notFound(VaultPath)
    case pathMismatch
    case unsupportedSchema(Int)
    case wrongEntityType(VaultPath)
    case inputOutput(String)
}
