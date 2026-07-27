import Foundation
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

extension VaultStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .conflict(path): "The file changed outside Local Todo: \(path.value). Reload it before saving."
        case let .destinationExists(path): "A file already exists at \(path.value)."
        case let .invalidVault(message): "Invalid vault: \(message)."
        case let .missingReference(path): "A referenced file is missing: \(path.value)."
        case let .notFound(path): "File not found: \(path.value)."
        case .pathMismatch: "The entity path does not match its vault-relative file path."
        case let .unsupportedSchema(version): "Vault schema version \(version) is not supported."
        case let .wrongEntityType(path): "The file type changed outside Local Todo: \(path.value)."
        case let .inputOutput(message): "File operation failed: \(message)."
        }
    }
}
