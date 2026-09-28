import Foundation
import LocalTodoDomain

public struct FilterDraftCheckpoint: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        "\(vaultIdentifier)|\(editorKey)"
    }

    public let vaultIdentifier: String
    public let editorKey: String
    public let originalName: String?
    public let baseRevision: String?
    public let generation: UInt64
    public let name: String
    public let view: TaskView
    public let text: String
    public let includeCompleted: Bool
    public let sort: TaskSort
    public let statuses: Set<TaskStatus>
    public let priorities: Set<TaskPriority>
    public let includesNoPriority: Bool
    public let projectPath: String
    public let areaPath: String
    public let tagsText: String
    public let scheduledFrom: String
    public let scheduledThrough: String
    public let deadlineFrom: String
    public let deadlineThrough: String

    public init(
        vaultIdentifier: String,
        editorKey: String,
        originalName: String?,
        baseRevision: String?,
        generation: UInt64,
        name: String,
        view: TaskView,
        text: String,
        includeCompleted: Bool,
        sort: TaskSort,
        statuses: Set<TaskStatus>,
        priorities: Set<TaskPriority>,
        includesNoPriority: Bool,
        projectPath: String,
        areaPath: String,
        tagsText: String,
        scheduledFrom: String,
        scheduledThrough: String,
        deadlineFrom: String,
        deadlineThrough: String
    ) {
        self.vaultIdentifier = vaultIdentifier
        self.editorKey = editorKey
        self.originalName = originalName
        self.baseRevision = baseRevision
        self.generation = generation
        self.name = name
        self.view = view
        self.text = text
        self.includeCompleted = includeCompleted
        self.sort = sort
        self.statuses = statuses
        self.priorities = priorities
        self.includesNoPriority = includesNoPriority
        self.projectPath = projectPath
        self.areaPath = areaPath
        self.tagsText = tagsText
        self.scheduledFrom = scheduledFrom
        self.scheduledThrough = scheduledThrough
        self.deadlineFrom = deadlineFrom
        self.deadlineThrough = deadlineThrough
    }
}

public actor FilterDraftCheckpointStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func checkpoints() throws -> [FilterDraftCheckpoint] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([FilterDraftCheckpoint].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ checkpoint: FilterDraftCheckpoint) throws {
        var values = try checkpoints()
        values.removeAll { $0.vaultIdentifier == checkpoint.vaultIdentifier && $0.editorKey == checkpoint.editorKey }
        values.append(checkpoint)
        try persist(values)
    }

    public func remove(vaultIdentifier: String, editorKey: String, through generation: UInt64) throws {
        let values = try checkpoints().filter {
            !($0.vaultIdentifier == vaultIdentifier && $0.editorKey == editorKey && $0.generation <= generation)
        }
        try persist(values)
    }

    private func persist(_ values: [FilterDraftCheckpoint]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directory = fileURL.deletingLastPathComponent()
        try directory.setResourceValues(resourceValues)
    }
}
