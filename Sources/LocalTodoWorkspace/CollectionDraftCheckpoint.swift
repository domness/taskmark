import Foundation
import LocalTodoDomain

public struct CollectionDraftCheckpoint: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        "\(vaultIdentifier)|\(path.value)"
    }

    public let vaultIdentifier: String
    public let path: VaultPath
    public let baseRevision: String
    public let generation: UInt64
    public let title: String
    public let body: String
    public let projectStatus: ProjectStatus?
    public let areaStatus: AreaStatus?
    public let area: VaultPath?
    public let tags: [String]

    public init(
        vaultIdentifier: String,
        path: VaultPath,
        baseRevision: String,
        generation: UInt64,
        title: String,
        body: String,
        projectStatus: ProjectStatus?,
        areaStatus: AreaStatus?,
        area: VaultPath?,
        tags: [String]
    ) {
        self.vaultIdentifier = vaultIdentifier
        self.path = path
        self.baseRevision = baseRevision
        self.generation = generation
        self.title = title
        self.body = body
        self.projectStatus = projectStatus
        self.areaStatus = areaStatus
        self.area = area
        self.tags = tags
    }
}

public actor CollectionDraftCheckpointStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func checkpoints() throws -> [CollectionDraftCheckpoint] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([CollectionDraftCheckpoint].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ checkpoint: CollectionDraftCheckpoint) throws {
        var values = try checkpoints()
        values.removeAll { $0.vaultIdentifier == checkpoint.vaultIdentifier && $0.path == checkpoint.path }
        values.append(checkpoint)
        try persist(values)
    }

    public func remove(vaultIdentifier: String, path: VaultPath, through generation: UInt64) throws {
        let values = try checkpoints().filter {
            !($0.vaultIdentifier == vaultIdentifier && $0.path == path && $0.generation <= generation)
        }
        try persist(values)
    }

    private func persist(_ values: [CollectionDraftCheckpoint]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directory = fileURL.deletingLastPathComponent()
        try directory.setResourceValues(resourceValues)
    }
}
