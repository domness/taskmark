import Foundation
import LocalTodoDomain

struct TaskListDisplayOptions: Codable, Equatable {
    var showsProject: Bool
    var showsArea: Bool
    var showsTags: Bool
    var grouping: TaskListGrouping
    var sort: TaskSort?

    static func defaults(for route: WorkspaceRoute) -> Self {
        switch route {
        case .project:
            Self(showsProject: false, showsArea: true, showsTags: true, grouping: .none)
        case .area:
            Self(showsProject: true, showsArea: false, showsTags: true, grouping: .none)
        case .tag:
            Self(showsProject: true, showsArea: true, showsTags: false, grouping: .none)
        default:
            Self(showsProject: true, showsArea: true, showsTags: true, grouping: .none)
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
