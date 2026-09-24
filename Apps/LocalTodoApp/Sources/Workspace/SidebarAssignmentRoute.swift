import LocalTodoDomain
import LocalTodoMarkdown
import SwiftUI

struct SidebarAssignmentRoute: View {
    let model: WorkspaceModel
    let route: WorkspaceRoute
    let title: String
    let systemImage: String
    let target: SidebarAssignmentTarget

    @State private var isTargeted = false

    var body: some View {
        SidebarRouteLabel(
            model: model, route: route, title: title,
            systemImage: isTargeted ? "arrow.down.circle" : systemImage
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            if isTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.14))
            }
        }
        .dropDestination(for: TaskDragItem.self) { values, _ in
            assign(values)
        } isTargeted: {
            isTargeted = $0
        }
        .help(target.helpText)
        .tag(route)
    }

    private func assign(_ values: [TaskDragItem]) -> Bool {
        guard model.taskDropPath(values, onto: target) != nil else { return false }
        Task { await model.applyTaskDrop(values, onto: target) }
        return true
    }
}

enum SidebarAssignmentTarget {
    case project(VaultPath)
    case area(VaultPath)
    case tag(String)

    var helpText: String {
        switch self {
        case .project: "Drop a task to assign this project"
        case .area: "Drop a task to assign this area"
        case .tag: "Drop a task to add this tag"
        }
    }

    func exists(in snapshot: VaultSnapshot?) -> Bool {
        switch self {
        case let .project(path): snapshot?.projects[path] != nil
        case let .area(path): snapshot?.areas[path] != nil
        case let .tag(tag):
            snapshot?.tasks.values.contains { $0.value.tags.contains(tag) } == true
                || snapshot?.projects.values.contains { $0.value.tags.contains(tag) } == true
                || snapshot?.areas.values.contains { $0.value.tags.contains(tag) } == true
        }
    }
}
