import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func recreateTask(_ draft: TaskDraft) async {
        guard draft.vaultSession == vaultSession,
              draft.sourceUnavailableMessage != nil,
              let store,
              let generation = draft.beginSaving()
        else { return }
        guard beginMutation(at: draft.path) else {
            draft.finishSaving()
            return
        }
        do {
            let updated = try draft.patch().applying(to: draft.sourceTask, now: Date())
            let record = try await store.create(.task(updated))
            endMutation(at: draft.path)
            guard draft.vaultSession == vaultSession else {
                draft.finishSaving()
                return
            }
            guard case let .task(savedTask) = record.value else {
                throw VaultStoreError.wrongEntityType(draft.path)
            }
            draft.acceptSave(
                VaultRecord(value: savedTask, revision: record.revision),
                generation: generation
            )
            merge(record)
            registerHistory(replacingWith: nil, at: draft.path, actionName: "Recreate Task")
            await refresh()
        } catch {
            endMutation(at: draft.path)
            draft.finishSaving()
            errorMessage = error.localizedDescription
        }
    }

    func saveTaskCopy(_ draft: TaskDraft) async {
        guard draft.vaultSession == vaultSession,
              draft.sourceUnavailableMessage != nil,
              !draft.canRecreateSource,
              let store,
              let snapshot,
              draft.beginSaving() != nil
        else { return }
        var copyPath: VaultPath?
        do {
            let local = try draft.patch().applying(to: draft.sourceTask, now: Date())
            let path = try nextTaskPath(title: local.title, snapshot: snapshot)
            copyPath = path
            guard beginMutation(at: path) else {
                draft.finishSaving()
                return
            }
            let copy = try recoveredCopy(of: local, at: path)
            let record = try await store.create(.task(copy))
            endMutation(at: path)
            try await adoptRecoveredCopy(record, from: draft, at: path)
        } catch {
            if let copyPath {
                endMutation(at: copyPath)
            }
            draft.finishSaving()
            errorMessage = error.localizedDescription
        }
    }

    private func adoptRecoveredCopy(
        _ record: VaultRecord<LocalTodoEntity>,
        from draft: TaskDraft,
        at path: VaultPath
    ) async throws {
        guard draft.vaultSession == vaultSession else {
            draft.finishSaving()
            return
        }
        guard case let .task(savedTask) = record.value else {
            throw VaultStoreError.wrongEntityType(path)
        }
        let copiedDraft = makeDraft(record: VaultRecord(value: savedTask, revision: record.revision))
        draft.transferCurrentValues(to: copiedDraft)
        autosaveTasks.removeValue(forKey: draft.path)?.cancel()
        taskDrafts.removeValue(forKey: draft.path)
        if selectedTaskPath == draft.path {
            selectedTaskPath = nil
        }
        merge(record)
        taskDrafts[path] = copiedDraft
        registerHistory(replacingWith: nil, at: path, actionName: "Save Task Copy")
        await refresh()
        selectedTaskPath = path
        if copiedDraft.isDirty {
            scheduleAutosave(for: copiedDraft)
        }
    }

    private func recoveredCopy(of task: TodoTask, at path: VaultPath) throws -> TodoTask {
        try TodoTask(
            path: path,
            title: task.title,
            status: task.status,
            priority: task.priority,
            scheduled: task.scheduled,
            deadline: task.deadline,
            project: task.project,
            area: task.area,
            tags: task.tags,
            recurrence: task.recurrence,
            resetChecklistOnRepeat: task.resetChecklistOnRepeat,
            body: task.body,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            completedAt: task.completedAt
        )
    }
}
