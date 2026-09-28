import LocalTodoDomain
import LocalTodoMarkdown

public extension WorkspaceSession {
    func updateTask(at path: VaultPath, patch: TaskPatch) async throws {
        try requireAvailable(path)
        guard let store, let record = snapshot?.tasks[path] else { throw WorkspaceSessionError.taskUnavailable(path) }
        let updated = try patch.applying(to: record.value, now: clock())
        try await persist(updated, replacing: record, actionName: "Edit Task", store: store)
    }

    func toggleCompletion(at path: VaultPath) async throws {
        try requireAvailable(path)
        guard let store, let record = snapshot?.tasks[path], let configuration = snapshot?.configuration else {
            throw WorkspaceSessionError.taskUnavailable(path)
        }
        let now = clock()
        let task = if record.value.status.isComplete {
            try TaskTransition.reopen(record.value, now: now)
        } else {
            try TaskTransition.complete(
                record.value,
                now: now,
                today: today(in: configuration),
                calendar: calendar(for: configuration)
            )
        }
        try await persist(
            task,
            replacing: record,
            actionName: record.value.status.isComplete ? "Reopen Task" : "Complete Task",
            store: store
        )
    }

    func deleteTask(at path: VaultPath) async throws {
        try requireAvailable(path)
        guard let store, let record = snapshot?.tasks[path] else { throw WorkspaceSessionError.taskUnavailable(path) }
        let content = try await store.taskContent(at: path, expectedRevision: record.revision)
        isSaving = true
        defer { isSaving = false }
        _ = try await store.delete(at: path, expectedRevision: record.revision)
        snapshot = try await store.snapshot()
        registerHistory(.init(path: path, before: .content(content), after: .absent, actionName: "Delete Task"))
    }

    @discardableResult
    func duplicateTask(at path: VaultPath) async throws -> VaultPath {
        try requireAvailable(path)
        guard let store, let record = snapshot?.tasks[path] else {
            throw WorkspaceSessionError.taskUnavailable(path)
        }
        isSaving = true
        defer { isSaving = false }
        let copy = try await store.duplicateTask(at: path, expectedRevision: record.revision, now: clock())
        snapshot = try await store.snapshot()
        try await recordCreatedEntity(at: copy.value.path, actionName: "Duplicate Task", store: store)
        return copy.value.path
    }

    private func persist(
        _ task: TodoTask,
        replacing record: VaultRecord<TodoTask>,
        actionName: String,
        store: VaultStore
    ) async throws {
        let before = try await store.taskContent(at: task.path, expectedRevision: record.revision)
        isSaving = true
        defer { isSaving = false }
        let updated = try await store.update(.task(task), expectedRevision: record.revision)
        snapshot = try await store.snapshot()
        let after = try await store.taskContent(at: task.path, expectedRevision: updated.revision)
        registerHistory(.init(
            path: task.path,
            before: .content(before),
            after: .content(after),
            actionName: actionName
        ))
    }
}
