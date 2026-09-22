import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    func assignTask(
        at taskPath: VaultPath,
        toProject projectPath: VaultPath,
        vaultSession intentSession: UUID
    ) async {
        guard intentSession == vaultSession,
              snapshot?.projects[projectPath] != nil,
              snapshot?.tasks[taskPath]?.value.project != projectPath
        else { return }
        var patch = TaskPatch()
        patch.project = .set(projectPath)
        await assignTask(
            at: taskPath,
            applying: patch,
            field: .project,
            actionName: "Change Project",
            vaultSession: intentSession
        )
    }

    func assignTask(
        at taskPath: VaultPath,
        toArea areaPath: VaultPath,
        vaultSession intentSession: UUID
    ) async {
        guard intentSession == vaultSession,
              snapshot?.areas[areaPath] != nil,
              snapshot?.tasks[taskPath]?.value.area != areaPath
        else { return }
        var patch = TaskPatch()
        patch.area = .set(areaPath)
        await assignTask(
            at: taskPath,
            applying: patch,
            field: .area,
            actionName: "Change Area",
            vaultSession: intentSession
        )
    }

    func assignTask(at path: VaultPath, addingTag tag: String, vaultSession intentSession: UUID) async {
        guard intentSession == vaultSession,
              allTags.contains(tag),
              let task = snapshot?.tasks[path]?.value,
              !task.tags.contains(tag)
        else { return }
        var patch = TaskPatch()
        patch.tags = .set(task.tags + [tag])
        await assignTask(
            at: path, applying: patch, field: .tags, actionName: "Add Tag", vaultSession: intentSession
        )
    }

    private func assignTask(
        at path: VaultPath,
        applying patch: TaskPatch,
        field: TaskOrganizationField,
        actionName: String,
        vaultSession intentSession: UUID
    ) async {
        guard intentSession == vaultSession,
              let store,
              let record = snapshot?.tasks[path],
              let draft = organizationDraft(at: path)
        else { return }
        guard let updated = organizationUpdate(patch, task: record.value) else { return }
        guard updated != record.value, beginMutation(at: path) else { return }
        let generation = draft.generation
        do {
            let saved = try await store.update(.task(updated), expectedRevision: record.revision)
            endMutation(at: path)
            guard intentSession == vaultSession, case let .task(savedTask) = saved.value else { return }
            draft.acceptOrganizationSave(
                VaultRecord(value: savedTask, revision: saved.revision),
                generation: generation,
                field: field
            )
            merge(saved)
            registerOrganizationHistory(
                draft,
                generation: generation,
                restoring: record.value,
                field: field,
                actionName: actionName
            )
            await refresh()
        } catch let error as VaultStoreError where error == .conflict(path) {
            endMutation(at: path)
            guard intentSession == vaultSession else { return }
            await refresh()
            errorMessage = "The task changed before it was reorganized. Try again."
        } catch {
            endMutation(at: path)
            guard intentSession == vaultSession else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func organizationUpdate(_ patch: TaskPatch, task: TodoTask) -> TodoTask? {
        do {
            return try patch.applying(to: task, now: Date())
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func registerOrganizationHistory(
        _ draft: TaskDraft,
        generation: UInt64,
        restoring task: TodoTask,
        field: TaskOrganizationField,
        actionName: String
    ) {
        guard draft.generation == generation else { return }
        let historyField: TaskTransitionField = switch field {
        case .project: .project
        case .area: .area
        case .tags: .tags
        }
        registerTaskTransitionHistory(restoring: task, fields: [historyField], actionName: actionName)
    }

    private func organizationDraft(at path: VaultPath) -> TaskDraft? {
        guard let record = snapshot?.tasks[path] else { return nil }
        guard !pendingMutationPaths.contains(path) else {
            errorMessage = "Wait for the current task change to finish before reorganizing it."
            return nil
        }
        let draft = taskDrafts[path] ?? makeDraft(record: record)
        guard !draft.hasConflicts, draft.sourceUnavailableMessage == nil, draft.validationError == nil else {
            errorMessage = "Resolve this task's pending changes before reorganizing it."
            return nil
        }
        guard !draft.isDirty, !draft.isSaving else {
            errorMessage = "Wait for this task's pending changes to save before reorganizing it."
            return nil
        }
        taskDrafts[path] = draft
        return draft
    }
}
