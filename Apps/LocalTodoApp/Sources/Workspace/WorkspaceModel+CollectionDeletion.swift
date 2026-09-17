import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func deleteCollection(at path: VaultPath) async {
        guard !isHistoryBusy, !pendingMutationPaths.contains(path), !deletingCollectionPaths.contains(path),
              snapshot?.projects[path] != nil || snapshot?.areas[path] != nil else { return }
        deletingCollectionPaths.insert(path)
        defer { deletingCollectionPaths.remove(path) }
        let session = vaultSession
        if let draft = projectDrafts[path] {
            if draft.isDirty {
                await updateProject(draft)
            }
            guard !draft.isDirty, draft.conflicts.isEmpty, draft.unavailableMessage == nil else {
                errorMessage = "Save or resolve this project’s pending changes before deleting it."
                return
            }
        }
        guard session == vaultSession, let store, let record = entityRecord(at: path),
              beginMutation(at: path) else { return }
        defer { endMutation(at: path) }
        do {
            let content = try await store.entityContent(at: path, expectedRevision: record.revision)
            _ = try await store.delete(at: path, expectedRevision: record.revision)
            autosaveTasks.removeValue(forKey: path)?.cancel()
            removeEntity(at: path)
            let name = if case .project = record.value {
                "Delete Project"
            } else {
                "Delete Area"
            }
            registerEntityContentHistory(content, at: path, deleting: false, actionName: name)
            if route == .project(path) || route == .area(path) {
                route = .inbox
            }
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }
}
