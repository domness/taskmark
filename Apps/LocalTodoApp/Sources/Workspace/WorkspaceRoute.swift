import LocalTodoDomain

enum WorkspaceRoute: Hashable {
    case today
    case inbox
    case next
    case all
    case search
    case project(VaultPath)
    case area(VaultPath)
    case tag(String)
    case priority(TaskPriority?)
    case issues

    var title: String {
        switch self {
        case .today: "Today"
        case .inbox: "Inbox"
        case .next: "Next"
        case .all: "All Tasks"
        case .search: "Search"
        case let .project(path): path.value.split(separator: "/").last.map(String.init) ?? path.value
        case let .area(path): path.value.split(separator: "/").last.map(String.init) ?? path.value
        case let .tag(tag): "#\(tag)"
        case let .priority(priority): priority?.rawValue.uppercased() ?? "No Priority"
        case .issues: "Issues"
        }
    }

    var listPreferencesKey: String {
        switch self {
        case .today: "today"
        case .inbox: "inbox"
        case .next: "next"
        case .all: "all"
        case .search: "search"
        case let .project(path): "project:\(path.value)"
        case let .area(path): "area:\(path.value)"
        case let .tag(tag): "tag:\(tag)"
        case let .priority(priority): "priority:\(priority?.rawValue ?? "none")"
        case .issues: "issues"
        }
    }
}
