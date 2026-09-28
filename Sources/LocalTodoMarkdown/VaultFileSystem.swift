import Foundation

public enum VaultWriteIntent: Equatable, Sendable {
    case creating
    case replacing
    case deleting
}

public enum VaultItemAvailability: Equatable, Sendable {
    case available
    case downloading
    case unavailable(String)
    case missing
}

public struct VaultProviderVersion: Equatable, Sendable, Identifiable {
    public let id: String
    public let modifiedAt: Date?
    public let localizedName: String?
    public let content: Data

    public init(id: String, modifiedAt: Date?, localizedName: String?, content: Data) {
        self.id = id
        self.modifiedAt = modifiedAt
        self.localizedName = localizedName
        self.content = content
    }
}

public protocol VaultFileSystem: Sendable {
    func coordinateReading(at url: URL, operation: (URL) throws -> Void) throws
    func coordinateMoving(
        from source: URL,
        to destination: URL,
        operation: (URL, URL) throws -> Void
    ) throws
    func coordinateWriting(
        at url: URL,
        intent: VaultWriteIntent,
        operation: (URL) throws -> Void
    ) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func createDirectory(at url: URL) throws
    func exists(at url: URL) -> Bool
    func availability(at url: URL) -> VaultItemAvailability
    /// Requests provider-backed content to become locally readable. Implementations
    /// must return immediately when the item is already local or has no download API.
    func requestMaterialization(at url: URL) throws
    /// Inspects the entry without following its final component, including dangling links.
    /// Returns false for missing entries; other metadata failures must throw.
    func isSymbolicLink(at url: URL) throws -> Bool
    func markdownFiles(in root: URL) throws -> [URL]
    func providerConflictFiles(in root: URL) throws -> [URL]
    func unresolvedProviderVersions(at url: URL) throws -> [VaultProviderVersion]
    func markProviderVersionsResolved(at url: URL, identifiers: Set<String>) throws
    func move(from source: URL, to destination: URL) throws
    func read(at url: URL) throws -> Data
    func remove(at url: URL) throws
    func removeEmptyDirectory(at url: URL) throws
    func removeFile(at url: URL) throws
    func writeAtomically(_ data: Data, to url: URL) throws
    func writeExclusively(_ data: Data, to url: URL) throws
}

public extension VaultFileSystem {
    func coordinateReading(at url: URL, operation: (URL) throws -> Void) throws {
        try operation(url)
    }

    func availability(at url: URL) -> VaultItemAvailability {
        exists(at: url) ? .available : .missing
    }

    func requestMaterialization(at _: URL) throws {}

    func providerConflictFiles(in root: URL) throws -> [URL] {
        var files = try markdownFiles(in: root)
        for relativePath in [LocalTodoSchema.manifestPath, VaultStore.savedFiltersPath, ".config/style.css"] {
            let url = root.appendingPathComponent(relativePath)
            if exists(at: url) {
                files.append(url)
            }
        }
        return files
    }

    func unresolvedProviderVersions(at _: URL) throws -> [VaultProviderVersion] {
        []
    }

    func markProviderVersionsResolved(at _: URL, identifiers: Set<String>) throws {
        guard identifiers.isEmpty else {
            throw VaultStoreError.inputOutput("This filesystem cannot resolve provider versions")
        }
    }

    func readCoordinated(at url: URL) throws -> Data {
        var result: Data?
        try coordinateReading(at: url) { coordinatedURL in
            guard coordinatedURL.standardizedFileURL == url.standardizedFileURL else {
                throw VaultStoreError.inputOutput("File provider redirected a coordinated read")
            }
            result = try read(at: coordinatedURL)
        }
        guard let result else {
            throw VaultStoreError.inputOutput("Coordinated read did not run")
        }
        return result
    }
}
