import Foundation
import Yams

public struct VaultConfigurationRecord: Equatable, Sendable {
    public let value: VaultConfiguration
    public let revision: FileRevision
}

public enum VaultConfigurationError: LocalizedError, Equatable {
    case conflict

    public var errorDescription: String? {
        "The vault configuration changed externally. Reload the time zone and try again."
    }
}

extension VaultStore {
    public func configurationRecord() throws -> VaultConfigurationRecord {
        let url = try configurationURL()
        let data = try performIO { try fileSystem.read(at: url) }
        return try configurationRecord(data)
    }

    public func setTimezone(_ timezone: String?, expectedRevision: FileRevision) throws -> VaultConfigurationRecord {
        guard timezone == nil || timezone.flatMap(TimeZone.init(identifier:)) != nil else {
            throw VaultStoreError.invalidVault("Choose a valid IANA time zone.")
        }
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
                _ = try configurationRecord(data)
                guard let source = String(data: data, encoding: .utf8),
                      var mapping = try Yams.compose(yaml: source)?.mapping
                else {
                    throw VaultStoreError.invalidVault("The manifest must be a YAML mapping.")
                }
                mapping[.scalar(.init("timezone"))] = timezone.map { .scalar(.init($0)) }
                let updated = try Data(Yams.serialize(node: .mapping(mapping)).utf8)
                let record = try configurationRecord(updated)
                try fileSystem.writeAtomically(updated, to: coordinatedURL)
                result = record
            }
        }
        guard let result else { throw VaultStoreError.inputOutput("Coordinated time-zone update did not run.") }
        return result
    }

    private func configurationRecord(_ data: Data) throws -> VaultConfigurationRecord {
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
        for component in [".localtodo", LocalTodoSchema.manifestPath] {
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
