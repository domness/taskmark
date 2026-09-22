import LocalTodoDomain

extension WorkspaceModel {
    func taskDropPath(_ items: [TaskDragItem], onto target: SidebarAssignmentTarget) -> VaultPath? {
        guard items.count == 1, let item = items.first,
              item.vaultSession == vaultSession,
              let path = try? VaultPath(item.path),
              snapshot?.tasks[path] != nil,
              target.exists(in: snapshot)
        else { return nil }
        return path
    }

    func applyTaskDrop(_ items: [TaskDragItem], onto target: SidebarAssignmentTarget) async {
        // Validate again after dispatch: the window may have switched vaults or refreshed.
        guard let path = taskDropPath(items, onto: target), let item = items.first else { return }
        switch target {
        case let .project(project):
            await assignTask(at: path, toProject: project, vaultSession: item.vaultSession)
        case let .area(area):
            await assignTask(at: path, toArea: area, vaultSession: item.vaultSession)
        case let .tag(tag):
            await assignTask(at: path, addingTag: tag, vaultSession: item.vaultSession)
        }
    }
}
