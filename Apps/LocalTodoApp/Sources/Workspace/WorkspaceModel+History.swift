import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

extension WorkspaceModel {
    var canPerformHistory: Bool {
        !isHistoryBusy
            && pendingMutationPaths.isEmpty
            && !hasDirtyDrafts
            && !filterState.isSaving
    }

    func setUndoManager(_ undoManager: UndoManager?) {
        guard self.undoManager !== undoManager else { return }
        self.undoManager?.removeAllActions()
        self.undoManager = undoManager
    }

    func performUndo() {
        guard canPerformHistory else { return }
        undoManager?.undo()
    }

    func performRedo() {
        guard canPerformHistory else { return }
        undoManager?.redo()
    }

    func clearHistory() {
        undoManager?.removeAllActions()
    }

    func registerHistory(replacingWith entity: LocalTodoEntity?, at path: VaultPath, actionName: String) {
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                model.performHistory(replacingWith: entity, at: path, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
    }

    func registerTaskTransitionHistory(
        restoring task: TodoTask,
        fields: Set<TaskTransitionField>,
        actionName: String
    ) {
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                model.performTaskTransitionHistory(restoring: task, fields: fields, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
    }

    func changeDraft<Value: Equatable>(
        _ draft: TaskDraft,
        keyPath: ReferenceWritableKeyPath<TaskDraft, Value>,
        to value: Value,
        actionName: String
    ) {
        let previous = draft[keyPath: keyPath]
        guard previous != value else { return }
        registerDraftHistory(draft, keyPath: keyPath, restoring: previous, actionName: actionName)
        draft[keyPath: keyPath] = value
    }

    func registerDraftHistory<Value: Equatable>(
        _ draft: TaskDraft,
        keyPath: ReferenceWritableKeyPath<TaskDraft, Value>,
        restoring value: Value,
        actionName: String
    ) {
        let action = DraftHistoryAction(
            draft: draft,
            keyPath: keyPath,
            value: value,
            actionName: actionName
        )
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                action.draft.isPlanningTransition = action.draft.isPlanningTransition || action.planningTransition
                model.changeDraft(
                    action.draft,
                    keyPath: action.keyPath,
                    to: action.value,
                    actionName: action.actionName
                )
            }
        }
        undoManager?.setActionName(actionName)
    }

    func merge(_ record: VaultRecord<LocalTodoEntity>) {
        guard let snapshot else { return }
        modelEpoch += 1
        var tasks = snapshot.tasks
        var projects = snapshot.projects
        var areas = snapshot.areas
        switch record.value {
        case let .task(task):
            tasks[task.path] = VaultRecord(value: task, revision: record.revision)
        case let .project(project):
            projects[project.path] = VaultRecord(value: project, revision: record.revision)
        case let .area(area):
            areas[area.path] = VaultRecord(value: area, revision: record.revision)
        }
        self.snapshot = VaultSnapshot(
            generation: snapshot.generation,
            configuration: snapshot.configuration,
            tasks: tasks,
            projects: projects,
            areas: areas,
            diagnostics: snapshot.diagnostics
        )
    }

    func removeEntity(at path: VaultPath) {
        guard let snapshot else { return }
        modelEpoch += 1
        var tasks = snapshot.tasks
        var projects = snapshot.projects
        var areas = snapshot.areas
        tasks.removeValue(forKey: path)
        projects.removeValue(forKey: path)
        areas.removeValue(forKey: path)
        taskDrafts.removeValue(forKey: path)
        projectDrafts.removeValue(forKey: path)
        if selectedTaskPath == path {
            selectedTaskPath = nil
        }
        self.snapshot = VaultSnapshot(
            generation: snapshot.generation,
            configuration: snapshot.configuration,
            tasks: tasks,
            projects: projects,
            areas: areas,
            diagnostics: snapshot.diagnostics
        )
    }

    func containsExternalChanges(from previous: VaultSnapshot, to next: VaultSnapshot) -> Bool {
        revisionsChanged(previous.tasks, next.tasks)
            || revisionsChanged(previous.projects, next.projects)
            || revisionsChanged(previous.areas, next.areas)
    }

    func beginMutation(at path: VaultPath) -> Bool {
        guard !pendingMutationPaths.contains(path) else { return false }
        pendingMutationPaths.insert(path)
        modelEpoch += 1
        return true
    }

    func endMutation(at path: VaultPath) {
        pendingMutationPaths.remove(path)
    }

    private func performHistory(replacingWith replacement: LocalTodoEntity?, at path: VaultPath, actionName: String) {
        guard !isHistoryBusy, pendingMutationPaths.isEmpty else { return }
        let inverse = entityRecord(at: path)?.value
        guard replacement != nil || inverse != nil else { return }
        guard beginMutation(at: path) else { return }
        registerHistory(replacingWith: inverse, at: path, actionName: actionName)
        isHistoryBusy = true
        let session = vaultSession
        Task { await applyHistory(replacingWith: replacement, at: path, session: session) }
    }

    private func performTaskTransitionHistory(
        restoring task: TodoTask,
        fields: Set<TaskTransitionField>,
        actionName: String
    ) {
        guard !isHistoryBusy, pendingMutationPaths.isEmpty,
              let current = snapshot?.tasks[task.path]?.value
        else { return }
        guard beginMutation(at: task.path) else { return }
        registerTaskTransitionHistory(restoring: current, fields: fields, actionName: actionName)
        isHistoryBusy = true
        let session = vaultSession
        Task { await applyTaskTransitionHistory(restoring: task, fields: fields, session: session) }
    }

    private func applyTaskTransitionHistory(
        restoring task: TodoTask,
        fields: Set<TaskTransitionField>,
        session: UUID
    ) async {
        defer {
            endMutation(at: task.path)
            isHistoryBusy = false
        }
        guard session == vaultSession, let store, let current = snapshot?.tasks[task.path] else { return }
        do {
            let restored = try restoring(fields, from: task, onto: current.value)
            let record = try await store.update(.task(restored), expectedRevision: current.revision)
            guard session == vaultSession else { return }
            merge(record)
            await refresh()
        } catch {
            clearHistory()
            await refresh()
            errorMessage = error.localizedDescription
        }
    }

    private func applyHistory(replacingWith replacement: LocalTodoEntity?, at path: VaultPath, session: UUID) async {
        defer {
            endMutation(at: path)
            isHistoryBusy = false
        }
        guard session == vaultSession, let store else { return }
        do {
            if let replacement {
                let record: VaultRecord<LocalTodoEntity> = if let current = entityRecord(at: path) {
                    try await store.update(replacement, expectedRevision: current.revision)
                } else {
                    try await store.create(replacement)
                }
                guard session == vaultSession else { return }
                merge(record)
            } else if let current = entityRecord(at: path) {
                _ = try await store.delete(at: path, expectedRevision: current.revision)
                guard session == vaultSession else { return }
                removeEntity(at: path)
            }
            await refresh()
        } catch {
            clearHistory()
            await refresh()
            errorMessage = error.localizedDescription
        }
    }

    private func entityRecord(at path: VaultPath) -> VaultRecord<LocalTodoEntity>? {
        if let record = snapshot?.tasks[path] {
            return VaultRecord(value: .task(record.value), revision: record.revision)
        }
        if let record = snapshot?.projects[path] {
            return VaultRecord(value: .project(record.value), revision: record.revision)
        }
        if let record = snapshot?.areas[path] {
            return VaultRecord(value: .area(record.value), revision: record.revision)
        }
        return nil
    }

    private func restoring(
        _ fields: Set<TaskTransitionField>,
        from task: TodoTask,
        onto current: TodoTask
    ) throws -> TodoTask {
        try TodoTask(
            path: current.path,
            title: current.title,
            status: fields.contains(.status) ? task.status : current.status,
            priority: current.priority,
            scheduled: fields.contains(.scheduled) ? task.scheduled : current.scheduled,
            deadline: fields.contains(.deadline) ? task.deadline : current.deadline,
            project: fields.contains(.project) ? task.project : current.project,
            area: fields.contains(.area) ? task.area : current.area,
            tags: current.tags,
            recurrence: current.recurrence,
            resetChecklistOnRepeat: current.resetChecklistOnRepeat,
            body: fields.contains(.body) ? task.body : current.body,
            createdAt: current.createdAt,
            updatedAt: Date(),
            completedAt: fields.contains(.completedAt) ? task.completedAt : current.completedAt
        )
    }

    private func revisionsChanged<Value: Equatable & Sendable>(
        _ previous: [VaultPath: VaultRecord<Value>],
        _ next: [VaultPath: VaultRecord<Value>]
    ) -> Bool {
        let paths = Set(previous.keys).union(next.keys)
        return paths.contains { previous[$0]?.revision != next[$0]?.revision }
    }
}

enum TaskTransitionField: Hashable {
    case body
    case status
    case scheduled
    case deadline
    case project
    case area
    case completedAt
}
