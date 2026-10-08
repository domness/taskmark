import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

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
        case let .focus(target):
            await moveTask(at: path, to: target, vaultSession: item.vaultSession)
        }
    }

    func moveTask(
        at path: VaultPath,
        to target: FocusDropTarget,
        vaultSession intentSession: UUID
    ) async {
        guard intentSession == vaultSession,
              let store,
              let snapshot,
              let record = snapshot.tasks[path],
              let draft = dropReadyDraft(for: record)
        else { return }
        do {
            let now = clock()
            let updated = try focusDropUpdate(target, task: record.value, now: now, snapshot: snapshot)
            guard updated != record.value, beginMutation(at: path) else { return }
            let generation = draft.generation
            do {
                let saved = try await store.update(.task(updated), expectedRevision: record.revision)
                endMutation(at: path)
                guard intentSession == vaultSession, case let .task(savedTask) = saved.value else { return }
                let fields = transitionFields(from: record.value, to: savedTask)
                draft.acceptFocusDropSave(
                    VaultRecord(value: savedTask, revision: saved.revision),
                    generation: generation,
                    fields: fields
                )
                merge(saved)
                registerTaskTransitionHistory(
                    restoring: record.value,
                    fields: fields,
                    actionName: target == .completed ? "Complete Task" : "Move to \(target.title)"
                )
                await refresh()
            } catch {
                endMutation(at: path)
                throw error
            }
        } catch let error as VaultStoreError where error == .conflict(path) {
            guard intentSession == vaultSession else { return }
            await refresh()
            errorMessage = "The task changed before it was moved. Try again."
        } catch {
            guard intentSession == vaultSession else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func focusDropUpdate(
        _ target: FocusDropTarget,
        task: TodoTask,
        now: Date,
        snapshot: VaultSnapshot
    ) throws -> TodoTask {
        if target == .completed {
            if task.status == .done {
                return task
            }
            if task.status == .canceled {
                var patch = TaskPatch()
                patch.status = .set(.done)
                return try patch.applying(to: task, now: now)
            }
            return try TaskTransition.complete(
                task,
                now: now,
                today: today(configuration: snapshot.configuration, now: now),
                calendar: vaultCalendar
            )
        }
        var patch = TaskPatch()
        switch target {
        case .inbox:
            patch.status = .set(.inbox)
        case .today:
            patch.status = .set(.next)
            patch.scheduled = try .set(today(configuration: snapshot.configuration, now: now))
        case .next:
            patch.status = .set(.next)
        case .upcoming:
            patch.status = .set(.next)
            let tomorrow = try today(configuration: snapshot.configuration, now: now)
                .adding(DateComponents(day: 1), calendar: vaultCalendar)
            patch.scheduled = .set(tomorrow)
        case .waiting:
            patch.status = .set(.waiting)
        case .someday:
            patch.status = .set(.someday)
        case .completed:
            break
        }
        return try patch.applying(to: task, now: now)
    }

    private func dropReadyDraft(for record: VaultRecord<TodoTask>) -> TaskDraft? {
        guard !pendingMutationPaths.contains(record.value.path) else {
            errorMessage = "Wait for the current task change to finish before moving it."
            return nil
        }
        let draft = taskDrafts[record.value.path] ?? makeDraft(record: record)
        guard !draft.hasConflicts, draft.sourceUnavailableMessage == nil, draft.validationError == nil else {
            errorMessage = "Resolve this task's pending changes before moving it."
            return nil
        }
        guard !draft.isDirty, !draft.isSaving else {
            errorMessage = "Wait for this task's pending changes to save before moving it."
            return nil
        }
        taskDrafts[record.value.path] = draft
        return draft
    }
}
