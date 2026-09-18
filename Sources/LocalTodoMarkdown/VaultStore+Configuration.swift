import Foundation

public struct VaultConfigurationRecord: Equatable, Sendable {
    public let value: VaultConfiguration
    public let revision: FileRevision
}

public enum VaultConfigurationError: LocalizedError, Equatable {
    case conflict

    public var errorDescription: String? {
        "The vault configuration changed externally. Reload it and resolve conflicting preferences before saving."
    }
}

extension VaultStore {
    public func configurationRecord() throws -> VaultConfigurationRecord {
        let url = try configurationURL()
        let data = try performIO { try fileSystem.read(at: url) }
        return try decodeConfigurationRecord(data)
    }

    public func setTimezone(_ timezone: String?, expectedRevision: FileRevision) throws -> VaultConfigurationRecord {
        guard timezone == nil || timezone.flatMap(TimeZone.init(identifier:)) != nil else {
            throw VaultStoreError.invalidVault("Choose a valid IANA time zone.")
        }
        return try updateConfiguration(expectedRevision: expectedRevision) {
            try ConfigurationDocument.timezone(timezone, in: $0)
        }
    }

    public func setPreferences(
        _ changes: [String: ConfigurationValue], expectedRevision: FileRevision
    ) throws -> VaultConfigurationRecord {
        try updateConfiguration(expectedRevision: expectedRevision) {
            try ConfigurationDocument.preferences(changes, in: $0)
        }
    }

    private func updateConfiguration(
        expectedRevision: FileRevision, edit: (Data) throws -> Data
    ) throws -> VaultConfigurationRecord {
        let url = try configurationURL()
        var result: VaultConfigurationRecord?
        try performIO {
            try fileSystem.coordinateWriting(at: url, intent: .replacing) { coordinatedURL in
                guard coordinatedURL.standardizedFileURL == url.standardizedFileURL else {
                    throw VaultConfigurationError.conflict
                }
                _ = try configurationURL()
                let data = try fileSystem.read(at: coordinatedURL)
                guard FileRevision(data: data) == expectedRevision else { throw VaultConfigurationError.conflict }
                _ = try decodeConfigurationRecord(data)
                let updated = try edit(data)
                let record = try decodeConfigurationRecord(updated)
                try fileSystem.writeAtomically(updated, to: coordinatedURL)
                result = record
            }
        }
        guard let result else { throw VaultStoreError.inputOutput("Coordinated configuration update did not run.") }
        return result
    }

    func decodeConfigurationRecord(_ data: Data) throws -> VaultConfigurationRecord {
        guard let source = String(data: data, encoding: .utf8) else {
            throw VaultStoreError.invalidVault("Manifest is not valid UTF-8.")
        }
        let configuration = try VaultConfiguration.decode(yaml: source)
        guard configuration.schema == LocalTodoSchema.currentVersion else {
            throw VaultStoreError.unsupportedSchema(configuration.schema)
        }
        if let timezone = configuration.timezone, TimeZone(identifier: timezone) == nil {
            throw VaultStoreError.invalidVault("Invalid timezone: \(timezone)")
        }
        return VaultConfigurationRecord(value: configuration, revision: FileRevision(data: data))
    }

    private func configurationURL() throws -> URL {
        for component in [".config", LocalTodoSchema.manifestPath] {
            try validateConfigurationComponent(component)
        }
        return root.appendingPathComponent(LocalTodoSchema.manifestPath)
    }

    private func validateConfigurationComponent(_ component: String) throws {
        if try fileSystem.isSymbolicLink(at: root.appendingPathComponent(component)) {
            throw VaultStoreError.invalidVault("Vault configuration must not use symbolic links.")
        }
    }
}
