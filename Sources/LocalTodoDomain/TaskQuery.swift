import Foundation

public struct TaskQuery: Equatable, Sendable {
    public var scope: TaskScope
    public var text: String
    public var filters: TaskFilters
    public var includeCompleted: Bool
    public var sort: TaskSort

    public init(
        scope: TaskScope = .all,
        text: String = "",
        filters: TaskFilters = TaskFilters(),
        includeCompleted: Bool = false,
        sort: TaskSort = .path
    ) {
        self.scope = scope
        self.text = text
        self.filters = filters
        self.includeCompleted = includeCompleted
        self.sort = sort
    }

    public func matches(_ task: TodoTask, today: CalendarDate) -> Bool {
        if !includeCompleted, task.status.isComplete {
            return false
        }
        guard matchesScope(task, today: today), filters.matches(task) else {
            return false
        }
        return matchesText(task)
    }

    public func results(from tasks: some Sequence<TodoTask>, today: CalendarDate) -> [TodoTask] {
        tasks
            .filter { matches($0, today: today) }
            .sorted(by: sort.precedes)
    }

    private func matchesScope(_ task: TodoTask, today: CalendarDate) -> Bool {
        switch scope {
        case .all:
            true
        case .today:
            !task.status
                .isComplete && (task.scheduled.map { $0 <= today } == true || task.deadline.map { $0 <= today } == true)
        case .inbox:
            task.status == .inbox
        case .next:
            task.status == .next
        case .waiting:
            task.status == .waiting
        case .someday:
            task.status == .someday
        case .upcoming:
            !task.status.isComplete
                && (task.scheduled.map { $0 > today } == true || task.deadline.map { $0 > today } == true)
        default:
            matchesMetadataScope(task)
        }
    }

    private func matchesMetadataScope(_ task: TodoTask) -> Bool {
        switch scope {
        case let .project(path):
            task.project == path
        case let .area(path):
            task.area == path
        case let .tag(tag):
            task.tags.contains(tag)
        case let .priority(priority):
            task.priority == priority
        default: false
        }
    }

    private func matchesText(_ task: TodoTask) -> Bool {
        guard !text.isEmpty else {
            return true
        }
        let needle = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let haystack = ([task.title, task.body] + task.tags)
            .joined(separator: "\n")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return haystack.contains(needle)
    }
}
