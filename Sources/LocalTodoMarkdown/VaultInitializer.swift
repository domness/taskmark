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
        if fileSystem.exists(at: root) {
            let contents = try fileSystem.contentsOfDirectory(at: root)
            if !contents.isEmpty {
                throw VaultStoreError.invalidVault("Directory is not empty")
            }
        }
        let rootExisted = fileSystem.exists(at: root)
        let configurationDirectory = manifest.deletingLastPathComponent()
        let configuration = VaultConfiguration(timezone: timezone)
        guard let data = try configuration.encoded().data(using: .utf8) else {
            throw VaultStoreError.inputOutput("Unable to encode manifest")
        }
        do {
            try fileSystem.createDirectory(at: root)
            try fileSystem.createDirectory(at: configurationDirectory)
            let rootContents = try fileSystem.contentsOfDirectory(at: root)
            guard rootContents.count == 1,
                  rootContents[0].standardizedFileURL == configurationDirectory.standardizedFileURL,
                  try fileSystem.contentsOfDirectory(at: configurationDirectory).isEmpty
            else {
                throw VaultStoreError.invalidVault("Directory changed during initialization")
            }
            try fileSystem.writeExclusively(data, to: manifest)
        } catch {
            try? fileSystem.removeEmptyDirectory(at: configurationDirectory)
            if !rootExisted {
                try? fileSystem.removeEmptyDirectory(at: root)
            }
            if fileSystem.exists(at: manifest) {
                throw VaultStoreError.invalidVault("Manifest already exists")
            }
            throw error
        }
    }
}
