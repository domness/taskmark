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
            .dropDestination(for: SidebarDragItem.self) { values, _ in
                guard values.count == 1, let item = values.first else { return false }
                switch item {
                case let .task(task): return assign([task])
                case let .collection(collection):
                    return model.reorderCollection(collection, before: target.path, in: target.collection)
                }
            } isTargeted: {
                isTargeted = $0
            }
            .help(target.helpText)
            .draggable(CollectionDragItem(
                path: target.path.value,
                collection: target.collection,
                session: model.vaultSession
            ))
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

    var path: VaultPath {
        switch self {
        case let .project(path), let .area(path): path
        }
    }

    var collection: SidebarCollection {
        switch self {
        case .project: .project
        case .area: .area
        }
    }

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
