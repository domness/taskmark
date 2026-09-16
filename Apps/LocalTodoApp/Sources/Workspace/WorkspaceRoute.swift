import LocalTodoDomain

enum WorkspaceRoute: Hashable {
    case today, inbox, next, upcoming, waiting, someday, all, search, filters, issues
    case savedFilter(String)
    case project(VaultPath)
    case area(VaultPath)
    case tag(String)
    case priority(TaskPriority?)

    var taskView: TaskView? {
        switch self {
        case .today: .today
        case .inbox: .inbox
        case .next: .next
        case .upcoming: .upcoming
        case .waiting: .waiting
        case .someday: .someday
        case .all: .all
        default: nil
        }
    }

    var scope: TaskScope {
        if let taskView {
            return taskView.scope
        }
        return switch self {
        case let .project(path): .project(path)
        case let .area(path): .area(path)
        case let .tag(tag): .tag(tag)
        case let .priority(priority): .priority(priority)
        default: .all
        }
    }

    var title: String {
        if let taskView {
            return taskView == .all ? "All Tasks" : taskView.rawValue.capitalized
        }
        return switch self {
        case .search: "Search"
        case .filters: "Filter Tasks"
        case let .savedFilter(name): name
        case let .project(path), let .area(path): path.value.split(separator: "/").last.map(String.init) ?? path.value
        case let .tag(tag): "#\(tag)"
        case let .priority(priority): priority?.rawValue.uppercased() ?? "No Priority"
        case .issues: "Issues"
        default: "Tasks"
        }
    }

    var listPreferencesKey: String {
        if let taskView {
            return taskView.rawValue
        }
        return switch self {
        case .search: "search"
        case .filters: "filters"
        case let .savedFilter(name): "filter:\(name)"
        case let .project(path): "project:\(path.value)"
        case let .area(path): "area:\(path.value)"
        case let .tag(tag): "tag:\(tag)"
        case let .priority(priority): "priority:\(priority?.rawValue ?? "none")"
        case .issues: "issues"
        default: "all"
        }
    }

    var defaultSort: TaskSort {
        switch self {
        case .today, .next, .waiting, .someday: .priority
        case .upcoming: .scheduled
        default: .path
        }
    }
}
