import Foundation
import LocalTodoDomain

struct TaskListDisplayOptions: Codable, Equatable {
    var showsProject: Bool
    var showsArea: Bool
    var showsTags: Bool
    var grouping: TaskListGrouping
    var sort: TaskSort?

    static func showsScheduledDate(_ date: CalendarDate?, route: WorkspaceRoute, today: CalendarDate?) -> Bool {
        guard let date else { return false }
        return route != .today || date != today
    }

    static func defaults(for route: WorkspaceRoute) -> Self {
        switch route {
        case .project:
            Self(showsProject: false, showsArea: false, showsTags: false, grouping: .none)
        case .area:
            Self(showsProject: true, showsArea: false, showsTags: false, grouping: .project)
        case .tag:
            Self(showsProject: true, showsArea: false, showsTags: false, grouping: .none)
        case .today, .upcoming:
            Self(showsProject: true, showsArea: false, showsTags: false, grouping: .project)
        default:
            Self(showsProject: true, showsArea: false, showsTags: false, grouping: .none)
        }
    }
}

enum TaskListGrouping: String, CaseIterable, Codable, Identifiable {
    case none
    case project
    case area

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .none: "None"
        case .project: "Project"
        case .area: "Area"
        }
    }
}

enum TaskListMetadataField {
    case project
    case area
    case tags
}
