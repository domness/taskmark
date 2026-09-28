import Foundation

public extension VaultStore {
    func resolveProviderConflict(
        at relativePath: String,
        choosing content: Data,
        expectedCurrentRevision: FileRevision,
        expectedVersionIdentifiers: Set<String>
    ) throws {
        let url = try providerConflictURL(for: relativePath)
        try performIO {
            try fileSystem.coordinateWriting(at: url, intent: .replacing) { coordinatedURL in
                guard coordinatedURL.standardizedFileURL == url.standardizedFileURL else {
                    throw VaultStoreError.providerConflictChanged(relativePath)
                }
                let current = try fileSystem.read(at: coordinatedURL)
                let versions = try fileSystem.unresolvedProviderVersions(at: coordinatedURL)
                guard FileRevision(data: current) == expectedCurrentRevision,
                      Set(versions.map(\.id)) == expectedVersionIdentifiers
                else {
                    throw VaultStoreError.providerConflictChanged(relativePath)
                }
                try fileSystem.writeAtomically(content, to: coordinatedURL)
                try fileSystem.markProviderVersionsResolved(
                    at: coordinatedURL,
                    identifiers: expectedVersionIdentifiers
                )
            }
        }
    }

    private func providerConflictURL(for relativePath: String) throws -> URL {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !normalized.hasPrefix("/"), !normalized.hasSuffix("/"),
              !normalized.contains("\0"),
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
        else {
            throw VaultStoreError.inputOutput("Invalid provider conflict path")
        }
        let url = root.appendingPathComponent(normalized).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else {
            throw VaultStoreError.inputOutput("Provider conflict path escapes the vault")
        }
        return url
    }
}
