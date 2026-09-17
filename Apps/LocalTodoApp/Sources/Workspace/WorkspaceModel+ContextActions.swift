import AppKit
import LocalTodoDomain
import LocalTodoMarkdown

enum TaskCopyFormat {
    case title, markdown, path
}

extension WorkspaceModel {
    func duplicateTask(at path: VaultPath) async {
        let session = vaultSession
        guard let record = await prepareTaskAction(at: path), session == vaultSession,
              let store, beginMutation(at: path) else { return }
        defer { endMutation(at: path) }
        do {
            let copy = try await store.duplicateTask(at: path, expectedRevision: record.revision, now: clock())
            merge(copy)
            let content = try await store.taskContent(at: copy.value.path, expectedRevision: copy.revision)
            registerTaskContentHistory(content, at: copy.value.path, deleting: true, actionName: "Duplicate Task")
            await refresh()
            editTask(at: copy.value.path)
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteTask(at path: VaultPath) async {
        guard !deletingTaskPaths.contains(path) else { return }
        deletingTaskPaths.insert(path)
        defer { deletingTaskPaths.remove(path) }
        let session = vaultSession
        guard let record = await prepareTaskAction(at: path), session == vaultSession,
              let store, beginMutation(at: path) else { return }
        defer { endMutation(at: path) }
        do {
            let content = try await store.taskContent(at: path, expectedRevision: record.revision)
            _ = try await store.delete(at: path, expectedRevision: record.revision)
            autosaveTasks.removeValue(forKey: path)?.cancel()
            removeEntity(at: path)
            registerTaskContentHistory(content, at: path, deleting: false, actionName: "Delete Task")
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func copyTask(at path: VaultPath, format: TaskCopyFormat) async {
        let session = vaultSession
        guard let record = await prepareTaskAction(at: path), session == vaultSession, let store else { return }
        do {
            let text: String
            switch format {
            case .title: text = record.value.title
            case .path: text = path.value
            case .markdown:
                let data = try await store.taskContent(at: path, expectedRevision: record.revision)
                guard let source = String(data: data, encoding: .utf8) else { return }
                text = source
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } catch { errorMessage = error.localizedDescription }
    }

    private func prepareTaskAction(at path: VaultPath) async -> VaultRecord<TodoTask>? {
        guard !isHistoryBusy, !pendingMutationPaths.contains(path) else { return nil }
        if let draft = taskDrafts[path] {
            if draft.isDirty {
                await updateTask(draft)
            }
            guard !draft.isDirty, !draft.hasConflicts, draft.sourceUnavailableMessage == nil else {
                errorMessage = "Save or resolve this task’s pending changes before continuing."
                return nil
            }
        }
        return snapshot?.tasks[path]
    }

    private func registerTaskContentHistory(_ data: Data, at path: VaultPath, deleting: Bool, actionName: String) {
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                guard model.canPerformHistory, model.beginMutation(at: path) else { return }
                model.registerTaskContentHistory(data, at: path, deleting: !deleting, actionName: actionName)
                model.isHistoryBusy = true
                Task { await model.applyTaskContentHistory(data, at: path, deleting: deleting) }
            }
        }
        undoManager?.setActionName(actionName)
    }

    private func applyTaskContentHistory(_ data: Data, at path: VaultPath, deleting: Bool) async {
        defer {
            endMutation(at: path)
            isHistoryBusy = false
        }
        guard let store else { return }
        do {
            if deleting {
                guard let revision = snapshot?.tasks[path]?.revision else { throw VaultStoreError.notFound(path) }
                _ = try await store.delete(at: path, expectedRevision: revision)
                removeEntity(at: path)
            } else {
                try await merge(store.restoreTaskContent(data, at: path))
            }
            await refresh()
        } catch {
            clearHistory()
            errorMessage = error.localizedDescription
        }
    }
}
