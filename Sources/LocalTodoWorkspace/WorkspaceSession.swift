import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Observation

@MainActor
@Observable
public final class WorkspaceSession {
    public internal(set) var snapshot: VaultSnapshot?
    public internal(set) var isSaving = false
    public private(set) var rootURL: URL?
    public internal(set) var savedFilters = SavedFilterRecord()
    public internal(set) var savedFilterError: String?
    public internal(set) var canUndo = false
    public internal(set) var canRedo = false

    @ObservationIgnored var store: VaultStore?
    @ObservationIgnored let clock: @Sendable () -> Date
    @ObservationIgnored var undoHistory = [PersistedHistoryAction]()
    @ObservationIgnored var redoHistory = [PersistedHistoryAction]()

    public init(clock: @escaping @Sendable () -> Date = Date.init) {
        self.clock = clock
    }

    public func open(root: URL) async throws {
        let candidate = VaultStore(root: root)
        let loaded = try await candidate.snapshot()
        store = candidate
        rootURL = root.standardizedFileURL
        snapshot = loaded
        await loadSavedFilters(from: candidate)
    }

    public func release() {
        store = nil
        rootURL = nil
        snapshot = nil
        savedFilters = SavedFilterRecord()
        savedFilterError = nil
        clearHistory()
    }

    public func refresh() async throws {
        guard let store else { return }
        snapshot = try await store.snapshot()
        await loadSavedFilters(from: store)
    }

    public func stylesheet() async throws -> String? {
        guard let store else { throw WorkspaceSessionError.noVault }
        return try await store.stylesheet()
    }

    public func tasks(
        for route: WorkspaceRoute,
        searchText: String = "",
        includeCompleted: Bool = false,
        sort: TaskSort? = nil
    ) -> [TodoTask] {
        guard let snapshot, let today = try? today(in: snapshot.configuration) else { return [] }
        if route == .search, searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        let query = savedQuery(for: route) ?? TaskQuery(
            scope: route.scope,
            text: route == .search ? searchText : "",
            includeCompleted: includeCompleted,
            sort: sort ?? defaultSort(for: route)
        )
        return applyingCustomOrder(query.results(from: snapshot.tasks.values.map(\.value), today: today), for: route)
    }

    @discardableResult
    public func capture(
        title: String, route: WorkspaceRoute, patch: TaskPatch = TaskPatch()
    ) async throws -> VaultPath {
        guard let store, let snapshot else { throw WorkspaceSessionError.noVault }
        let now = clock()
        let path = try nextTaskPath(title: title, snapshot: snapshot)
        let contextualTask = try capturedTask(path: path, title: title, route: route, now: now)
        let task = try patch.applying(to: contextualTask, now: now)
        isSaving = true
        defer { isSaving = false }
        _ = try await store.create(.task(task))
        self.snapshot = try await store.snapshot()
        try await recordCreatedEntity(at: path, actionName: "Add Task", store: store)
        return path
    }

    public func setPreferences(_ changes: [String: ConfigurationValue]) async throws {
        guard let store else { throw WorkspaceSessionError.noVault }
        isSaving = true
        defer { isSaving = false }
        let record = try await store.configurationRecord()
        _ = try await store.setPreferences(changes, expectedRevision: record.revision)
        snapshot = try await store.snapshot()
    }

    public func setTimezone(_ identifier: String?) async throws {
        guard let store else { throw WorkspaceSessionError.noVault }
        isSaving = true
        defer { isSaving = false }
        let record = try await store.configurationRecord()
        _ = try await store.setTimezone(identifier, expectedRevision: record.revision)
        snapshot = try await store.snapshot()
    }

    func requireAvailable(_ path: VaultPath) throws {
        guard let state = snapshot?.availability[path] else { return }
        guard state == .available else { throw WorkspaceSessionError.taskUnavailable(path) }
    }

    func today(in configuration: VaultConfiguration) throws -> CalendarDate {
        try CalendarDate(date: clock(), calendar: calendar(for: configuration))
    }

    func calendar(for configuration: VaultConfiguration) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let identifier = configuration.timezone, let zone = TimeZone(identifier: identifier) {
            calendar.timeZone = zone
        }
        return calendar
    }

    private func defaultSort(for route: WorkspaceRoute) -> TaskSort {
        if let configured = viewOptions(for: route).sort {
            return configured
        }
        return switch route {
        case .today, .next, .waiting, .someday: .priority
        case .upcoming: .scheduled
        default: .path
        }
    }

    private func nextTaskPath(title: String, snapshot: VaultSnapshot) throws -> VaultPath {
        let slug = title.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = slug.isEmpty ? "task" : slug
        var suffix = 1
        while true {
            let name = suffix == 1 ? base : "\(base)-\(suffix)"
            let path = try VaultPath("Tasks/\(name).md")
            if snapshot.tasks[path] == nil, snapshot.projects[path] == nil, snapshot.areas[path] == nil {
                return path
            }
            suffix += 1
        }
    }

    private func capturedTask(path: VaultPath, title: String, route: WorkspaceRoute, now: Date) throws -> TodoTask {
        let configuration = snapshot?.configuration ?? VaultConfiguration()
        let today = try today(in: configuration)
        var status: TaskStatus = .inbox
        var scheduled: CalendarDate?
        var project: VaultPath?
        var area: VaultPath?
        var tags = [String]()
        var priority: TaskPriority?
        switch route {
        case .today: status = .next; scheduled = today
        case .next: status = .next
        case .upcoming:
            status = .next
            scheduled = try today.adding(DateComponents(day: 1), calendar: calendar(for: configuration))
        case .waiting: status = .waiting
        case .someday: status = .someday
        case let .project(value): status = .next; project = value
        case let .area(value): status = .next; area = value
        case let .tag(value): tags = [value]
        case let .priority(value): priority = value
        default: break
        }
        return try TodoTask(
            path: path, title: title, status: status, priority: priority, scheduled: scheduled,
            project: project, area: area, tags: tags, createdAt: now, updatedAt: now
        )
    }
}

public enum WorkspaceSessionError: LocalizedError, Equatable {
    case noVault
    case taskUnavailable(VaultPath)
    case collectionUnavailable(VaultPath)
    case savedFiltersUnavailable
    case duplicateFilterName(String)

    public var errorDescription: String? {
        switch self {
        case .noVault: "No vault is open."
        case let .taskUnavailable(path): "The task is unavailable: \(path.value)"
        case let .collectionUnavailable(path): "The collection is unavailable: \(path.value)"
        case .savedFiltersUnavailable: "Saved filters could not be loaded. Reload before changing them."
        case let .duplicateFilterName(name): "A saved filter named \(name) already exists."
        }
    }
}

public enum WorkspaceCollectionKind: String, CaseIterable, Sendable {
    case project
    case area
}
