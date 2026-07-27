import Foundation

public enum VaultInitializer {
    public static func initialize(
        at root: URL,
        timezone: String? = nil,
        fileSystem: any VaultFileSystem = FoundationVaultFileSystem()
    ) throws {
        if let timezone, TimeZone(identifier: timezone) == nil {
            throw VaultStoreError.invalidVault("Invalid timezone: \(timezone)")
        }
        let manifest = root.appendingPathComponent(LocalTodoSchema.manifestPath)
        if fileSystem.exists(at: manifest) {
            throw VaultStoreError.invalidVault("Manifest already exists")
        }
        try fileSystem.createDirectory(at: root)
        try fileSystem.createDirectory(at: manifest.deletingLastPathComponent())
        let configuration = VaultConfiguration(timezone: timezone)
        guard let data = try configuration.encoded().data(using: .utf8) else {
            throw VaultStoreError.inputOutput("Unable to encode manifest")
        }
        try fileSystem.writeAtomically(data, to: manifest)
    }
}
