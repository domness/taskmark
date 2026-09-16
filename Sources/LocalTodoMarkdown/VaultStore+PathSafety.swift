import LocalTodoDomain

extension VaultStore {
    /// Rejects static symlinks below the root, not concurrent filesystem swaps.
    func validateEntityPath(_ path: VaultPath) throws {
        // Synthesized Codable can bypass VaultPath.init(_:).
        let validated = try VaultPath(path.value)
        guard validated.value == path.value else {
            throw DomainValidationError.invalidVaultPath
        }
        var current = root
        for component in validated.value.split(separator: "/") {
            current.appendPathComponent(String(component))
            if try performIO({ try fileSystem.isSymbolicLink(at: current) }) {
                throw VaultStoreError.invalidVault("Symbolic links are not allowed in entity path: \(path.value)")
            }
        }
    }
}
