import Foundation

public extension VaultStore {
    /// `.config` remains available for entities; only this CSS entry point has appearance meaning.
    func stylesheet() throws -> String? {
        var url = root
        for component in [".config", "style.css"] {
            url.appendPathComponent(component)
            guard try !fileSystem.isSymbolicLink(at: url) else {
                throw VaultStoreError.invalidVault("Stylesheet paths cannot contain symbolic links.")
            }
        }
        guard fileSystem.exists(at: url) else { return nil }
        let data = try performIO { try fileSystem.read(at: url) }
        guard data.count <= 65536, let source = String(data: data, encoding: .utf8) else {
            throw VaultStoreError.invalidVault("The stylesheet must be UTF-8 and at most 64 KiB.")
        }
        return source
    }
}
