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
        Label(title, systemImage: isTargeted ? "arrow.down.circle" : systemImage)
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
        guard let item = values.first,
              item.vaultSession == model.vaultSession,
              let taskPath = try? VaultPath(item.path),
              model.snapshot?.tasks[taskPath] != nil,
              target.exists(in: model.snapshot)
        else { return false }
        Task {
            switch target {
            case let .project(path):
                await model.assignTask(at: taskPath, toProject: path, vaultSession: item.vaultSession)
            case let .area(path):
                await model.assignTask(at: taskPath, toArea: path, vaultSession: item.vaultSession)
            }
        }
        return true
    }
}

enum SidebarAssignmentTarget {
    case project(VaultPath)
    case area(VaultPath)

    var helpText: String {
        switch self {
        case .project: "Drop a task to assign this project"
        case .area: "Drop a task to assign this area"
        }
    }

    func exists(in snapshot: VaultSnapshot?) -> Bool {
        switch self {
        case let .project(path): snapshot?.projects[path] != nil
        case let .area(path): snapshot?.areas[path] != nil
        }
    }
}
