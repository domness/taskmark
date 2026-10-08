import LocalTodoDomain

public enum WorkspaceRoute: Hashable, Sendable {
    case today, inbox, next, upcoming, waiting, someday, completed, all, search, filters, issues
    case savedFilter(String)
    case project(VaultPath)
    case area(VaultPath)
    case tag(String)
    case priority(TaskPriority?)

    public var scope: TaskScope {
        switch self {
        case .today: .today
        case .inbox: .inbox
        case .next: .next
        case .upcoming: .upcoming
        case .waiting: .waiting
        case .someday: .someday
        case .completed, .all, .search, .filters, .issues, .savedFilter: .all
        case let .project(path): .project(path)
        case let .area(path): .area(path)
        case let .tag(tag): .tag(tag)
        case let .priority(priority): .priority(priority)
        }
    }

    public var title: String {
        switch self {
        case .today: "Today"
        case .inbox: "Inbox"
        case .next: "Next"
        case .upcoming: "Upcoming"
        case .waiting: "Waiting"
        case .someday: "Someday"
        case .completed: "Completed"
        case .all: "All Tasks"
        case .search: "Search"
        case .filters: "Filter Tasks"
        case .issues: "Issues"
        case let .savedFilter(name): name
        case let .project(path), let .area(path):
            path.value.split(separator: "/").last.map(String.init) ?? path.value
        case let .tag(tag): "#\(tag)"
        case let .priority(priority): priority?.rawValue.uppercased() ?? "No Priority"
        }
    }

    public var taskView: TaskView? {
        switch self {
        case .today: .today
        case .inbox: .inbox
        case .next: .next
        case .upcoming: .upcoming
        case .waiting: .waiting
        case .someday: .someday
        case .completed: nil
        case .all: .all
        default: nil
        }
    }

    public var listPreferencesKey: String {
        if let taskView {
            return taskView.rawValue
        }
        return switch self {
        case .search: "search"
        case .filters: "filters"
        case .issues: "issues"
        case .completed: "completed"
        case let .savedFilter(name): "filter:\(name)"
        case let .project(path): "project:\(path.value)"
        case let .area(path): "area:\(path.value)"
        case let .tag(tag): "tag:\(tag)"
        case let .priority(priority): "priority:\(priority?.rawValue ?? "none")"
        default: "all"
        }
    }

    public var defaultSort: TaskSort {
        switch self {
        case .today, .next, .waiting, .someday: .priority
        case .completed: .updated
        case .upcoming: .scheduled
        default: .path
        }
    }
}
