import Foundation
import LocalTodoDomain

public struct CaptureDraftCheckpoint: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        "\(vaultIdentifier)|\(routeKey)"
    }

    public let vaultIdentifier: String
    public let routeKey: String
    public let generation: UInt64
    public let title: String
    public let notes: String
    public let status: TaskStatus?
    public let priority: TaskPriority?
    public let scheduled: CalendarDate?
    public let project: VaultPath?
    public let area: VaultPath?
    public let tags: [String]

    public init(
        vaultIdentifier: String,
        routeKey: String,
        generation: UInt64,
        title: String,
        notes: String,
        status: TaskStatus?,
        priority: TaskPriority?,
        scheduled: CalendarDate?,
        project: VaultPath?,
        area: VaultPath?,
        tags: [String]
    ) {
        self.vaultIdentifier = vaultIdentifier
        self.routeKey = routeKey
        self.generation = generation
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.scheduled = scheduled
        self.project = project
        self.area = area
        self.tags = tags
    }
}

public actor CaptureDraftCheckpointStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func checkpoints() throws -> [CaptureDraftCheckpoint] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([CaptureDraftCheckpoint].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ checkpoint: CaptureDraftCheckpoint) throws {
        var values = try checkpoints()
        values.removeAll { $0.vaultIdentifier == checkpoint.vaultIdentifier && $0.routeKey == checkpoint.routeKey }
        values.append(checkpoint)
        try persist(values)
    }

    public func remove(vaultIdentifier: String, routeKey: String, through generation: UInt64) throws {
        let values = try checkpoints().filter {
            !($0.vaultIdentifier == vaultIdentifier && $0.routeKey == routeKey && $0.generation <= generation)
        }
        try persist(values)
    }

    private func persist(_ values: [CaptureDraftCheckpoint]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directory = fileURL.deletingLastPathComponent()
        try directory.setResourceValues(resourceValues)
    }
}
