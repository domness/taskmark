import Foundation

public struct TaskQuery: Equatable, Sendable {
    public var scope: TaskScope
    public var text: String
    public var filters: TaskFilters
    public var includeCompleted: Bool

    public init(
        scope: TaskScope = .all,
        text: String = "",
        filters: TaskFilters = TaskFilters(),
        includeCompleted: Bool = false
    ) {
        self.scope = scope
        self.text = text
        self.filters = filters
        self.includeCompleted = includeCompleted
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
            .sorted { $0.path.value < $1.path.value }
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
        case let .project(path):
            task.project == path
        case let .area(path):
            task.area == path
        case let .tag(tag):
            task.tags.contains(tag)
        case let .priority(priority):
            task.priority == priority
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
