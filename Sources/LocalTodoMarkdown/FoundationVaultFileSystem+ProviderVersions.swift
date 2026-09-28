import Foundation

public extension FoundationVaultFileSystem {
    func providerConflictFiles(in root: URL) throws -> [URL] {
        var files = try markdownFiles(in: root)
        let configuration = root.appendingPathComponent(".config", isDirectory: true)
        guard exists(at: configuration) else { return files }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: configuration,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return files }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
            } else if values.isRegularFile == true {
                files.append(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    func unresolvedProviderVersions(at url: URL) throws -> [VaultProviderVersion] {
        try (NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).map { version in
            try VaultProviderVersion(
                id: providerIdentifier(for: version),
                modifiedAt: version.modificationDate,
                localizedName: version.localizedName,
                content: Data(contentsOf: version.url)
            )
        }.sorted { $0.id < $1.id }
    }

    func markProviderVersionsResolved(at url: URL, identifiers: Set<String>) throws {
        let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
        let matching = versions.filter { identifiers.contains(providerIdentifier(for: $0)) }
        guard Set(matching.map(providerIdentifier(for:))) == identifiers else {
            throw VaultStoreError.providerConflictChanged(url.lastPathComponent)
        }
        for version in matching {
            version.isResolved = true
        }
    }

    private func providerIdentifier(for version: NSFileVersion) -> String {
        let identifier = (try? NSKeyedArchiver.archivedData(
            withRootObject: version.persistentIdentifier,
            requiringSecureCoding: false
        )).map { FileRevision(data: $0).value } ?? String(describing: version.persistentIdentifier)
        let date = version.modificationDate?.timeIntervalSinceReferenceDate.description ?? "unknown"
        return "\(identifier)|\(date)"
    }
}
