import Foundation
import LocalTodoDomain

public struct TaskDraftCheckpoint: Codable, Equatable, Sendable {
    public let vaultIdentifier: String
    public let path: VaultPath
    public let baseRevision: String
    public let generation: UInt64
    public let title: String
    public let status: TaskStatus
    public let priority: TaskPriority?
    public let scheduled: CalendarDate?
    public let deadline: CalendarDate?
    public let project: VaultPath?
    public let area: VaultPath?
    public let tags: [String]
    public let body: String
    public let recurrence: RecurrenceEditorValue
    public let resetChecklistOnRepeat: Bool

    public init(
        vaultIdentifier: String,
        path: VaultPath,
        baseRevision: String,
        generation: UInt64,
        title: String,
        status: TaskStatus,
        priority: TaskPriority?,
        scheduled: CalendarDate?,
        deadline: CalendarDate?,
        project: VaultPath?,
        area: VaultPath?,
        tags: [String],
        body: String,
        recurrence: RecurrenceEditorValue = RecurrenceEditorValue(nil),
        resetChecklistOnRepeat: Bool = false
    ) {
        self.vaultIdentifier = vaultIdentifier
        self.path = path
        self.baseRevision = baseRevision
        self.generation = generation
        self.title = title
        self.status = status
        self.priority = priority
        self.scheduled = scheduled
        self.deadline = deadline
        self.project = project
        self.area = area
        self.tags = tags
        self.body = body
        self.recurrence = recurrence
        self.resetChecklistOnRepeat = resetChecklistOnRepeat
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        vaultIdentifier = try values.decode(String.self, forKey: .vaultIdentifier)
        path = try values.decode(VaultPath.self, forKey: .path)
        baseRevision = try values.decode(String.self, forKey: .baseRevision)
        generation = try values.decode(UInt64.self, forKey: .generation)
        title = try values.decode(String.self, forKey: .title)
        status = try values.decode(TaskStatus.self, forKey: .status)
        priority = try values.decodeIfPresent(TaskPriority.self, forKey: .priority)
        scheduled = try values.decodeIfPresent(CalendarDate.self, forKey: .scheduled)
        deadline = try values.decodeIfPresent(CalendarDate.self, forKey: .deadline)
        project = try values.decodeIfPresent(VaultPath.self, forKey: .project)
        area = try values.decodeIfPresent(VaultPath.self, forKey: .area)
        tags = try values.decode([String].self, forKey: .tags)
        body = try values.decode(String.self, forKey: .body)
        recurrence = try values.decodeIfPresent(RecurrenceEditorValue.self, forKey: .recurrence)
            ?? RecurrenceEditorValue(nil)
        resetChecklistOnRepeat = try values.decodeIfPresent(
            Bool.self,
            forKey: .resetChecklistOnRepeat
        ) ?? false
    }
}

public actor TaskDraftCheckpointStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func checkpoints() throws -> [TaskDraftCheckpoint] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([TaskDraftCheckpoint].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ checkpoint: TaskDraftCheckpoint) throws {
        var values = try checkpoints()
        values.removeAll {
            $0.vaultIdentifier == checkpoint.vaultIdentifier && $0.path == checkpoint.path
        }
        values.append(checkpoint)
        try persist(values)
    }

    public func remove(vaultIdentifier: String, path: VaultPath, through generation: UInt64) throws {
        let values = try checkpoints().filter {
            !($0.vaultIdentifier == vaultIdentifier && $0.path == path && $0.generation <= generation)
        }
        try persist(values)
    }

    private func persist(_ values: [TaskDraftCheckpoint]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(values)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directory = fileURL.deletingLastPathComponent()
        try directory.setResourceValues(values)
    }
}
