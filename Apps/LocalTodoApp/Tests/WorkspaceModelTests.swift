import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func workspaceCreatesAndRemembersVault() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-app-vault-tests-\(UUID().uuidString)")
    let suiteName = "LocalTodoAppTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let bookmarks = VaultBookmarkStore(defaults: defaults)
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    do {
        let model = WorkspaceModel(bookmarks: bookmarks)
        await model.createVault(at: root)
        #expect(model.errorMessage == nil)
        #expect(model.snapshot?.configuration.schema == LocalTodoSchema.currentVersion)
    }
    #expect(
        FileManager.default.fileExists(
            atPath: root.appendingPathComponent(LocalTodoSchema.manifestPath).path
        )
    )
    #expect(try bookmarks.restore()?.standardizedFileURL == root.standardizedFileURL)

    let restoredModel = WorkspaceModel(bookmarks: bookmarks)
    await restoredModel.restoreVault()

    #expect(restoredModel.errorMessage == nil)
    #expect(restoredModel.rootURL?.standardizedFileURL == root.standardizedFileURL)
}

@MainActor
@Test func workspaceUpdatesVisibleTitleImmediately() async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Original", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        model.route = .inbox
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.title = "Renamed"

        await model.updateTask(draft)

        #expect(model.snapshot?.tasks[path]?.value.title == "Renamed")
        #expect(model.visibleTasks.first?.title == "Renamed")
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func workspaceRebasesDraftOntoExternalFileChanges() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Original", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "Local notes"
        let externalStore = VaultStore(root: root)
        let externalRecord = try #require(try await externalStore.snapshot().tasks[path])
        var patch = TaskPatch()
        patch.title = .set("External title")
        let externalTask = try patch.applying(to: externalRecord.value, now: Date())
        _ = try await externalStore.update(.task(externalTask), expectedRevision: externalRecord.revision)

        await model.refresh()

        #expect(draft.title == "External title")
        #expect(draft.notes == "Local notes")
        #expect(draft.isDirty)
        await model.updateTask(draft)
        #expect(model.snapshot?.tasks[path]?.value.title == "External title")
        #expect(model.snapshot?.tasks[path]?.value.body == "Local notes")
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func workspaceDoesNotOverwriteOverlappingExternalChanges() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Original", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.title = "Local title"
        let externalStore = VaultStore(root: root)
        let externalRecord = try #require(try await externalStore.snapshot().tasks[path])
        var patch = TaskPatch()
        patch.title = .set("External title")
        let externalTask = try patch.applying(to: externalRecord.value, now: Date())
        _ = try await externalStore.update(.task(externalTask), expectedRevision: externalRecord.revision)

        await model.refresh()
        await model.updateTask(draft)

        #expect(draft.hasConflicts)
        #expect(try await externalStore.snapshot().tasks[path]?.value.title == "External title")
    }
}

@MainActor
@Test func workspaceAutosavesAfterChangingSelection() async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Original", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)

        draft.title = "Autosaved"
        model.selectTask(nil)
        try await Task.sleep(for: .milliseconds(700))

        #expect(model.snapshot?.tasks[path]?.value.title == "Autosaved")
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func workspaceFlushesPendingChangesWithoutWaitingForDebounce() async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Original", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.title = "Flushed"

        let saved = await model.flushTaskChanges()

        #expect(saved)
        #expect(model.snapshot?.tasks[path]?.value.title == "Flushed")
    }
}

@MainActor
@Test func workspaceTreatsQuickCaptureTextAsPendingChanges() async throws {
    try await withWorkspace { model, _ in
        model.beginQuickCapture()
        model.quickCaptureTitle = "Do not lose this"

        #expect(model.hasPendingDocumentChanges)
        #expect(await !(model.flushTaskChanges()))

        model.cancelQuickCapture()
        #expect(!model.hasPendingDocumentChanges)
    }
}

@MainActor
@Test func workspaceReturnsCompletedInboxTaskToInbox() async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Inbox task", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        let created = try #require(model.snapshot?.tasks[path])

        await model.completeTask(
            at: path,
            expectedRevision: created.revision,
            vaultSession: model.vaultSession
        )
        let completed = try #require(model.snapshot?.tasks[path])
        #expect(completed.value.status == .done)

        await model.completeTask(
            at: path,
            expectedRevision: completed.revision,
            vaultSession: model.vaultSession
        )

        #expect(model.snapshot?.tasks[path]?.value.status == .inbox)
        model.route = .inbox
        #expect(model.visibleTasks.contains { $0.path == path })
    }
}

@MainActor
@Test func workspaceShowsResultsOnlyForActiveSearch() async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Find this needle", vaultSession: model.vaultSession)
        await model.createTask(title: "Another task", vaultSession: model.vaultSession)
        model.route = .search

        #expect(model.visibleTasks.isEmpty)

        model.searchText = "needle"
        #expect(model.visibleTasks.map(\.title) == ["Find this needle"])

        model.route = .inbox
        #expect(model.searchText.isEmpty)
        #expect(model.visibleTasks.count == 2)
    }
}

@MainActor
@Test func workspaceUndoesAndRedoesTaskCreation() async throws {
    try await withWorkspace { model, _ in
        let undoManager = UndoManager()
        model.setUndoManager(undoManager)
        await model.createTask(title: "Undo me", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        #expect(undoManager.canUndo)

        model.performUndo()
        #expect(model.pendingMutationPaths == [path])
        try await waitForHistory(model)

        #expect(model.snapshot?.tasks[path] == nil)
        #expect(undoManager.canRedo)

        model.performRedo()
        try await waitForHistory(model)

        #expect(model.snapshot?.tasks[path]?.value.title == "Undo me")
    }
}

@MainActor
@Test func workspaceUndoesAndRedoesTaskCompletion() async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Complete me", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        let undoManager = UndoManager()
        model.setUndoManager(undoManager)
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "Written before completion"
        draft.scheduled = "2026-08-01"
        let created = try #require(model.snapshot?.tasks[path])
        await model.completeTask(
            at: path,
            expectedRevision: created.revision,
            vaultSession: model.vaultSession
        )
        await model.updateTask(draft)
        let completedAt = try #require(model.snapshot?.tasks[path]?.value.completedAt)
        #expect(model.snapshot?.tasks[path]?.value.status == .done)
        #expect(model.snapshot?.tasks[path]?.value.body == "Written before completion")
        #expect(model.snapshot?.tasks[path]?.value.scheduled?.description == "2026-08-01")

        model.performUndo()
        try await waitForHistory(model)

        #expect(model.snapshot?.tasks[path]?.value.status == .inbox)
        #expect(model.snapshot?.tasks[path]?.value.completedAt == nil)
        #expect(model.snapshot?.tasks[path]?.value.body == "Written before completion")
        #expect(model.snapshot?.tasks[path]?.value.scheduled?.description == "2026-08-01")

        model.performRedo()
        try await waitForHistory(model)

        #expect(model.snapshot?.tasks[path]?.value.status == .done)
        #expect(model.snapshot?.tasks[path]?.value.completedAt == completedAt)
    }
}

@MainActor
func withWorkspace(
    _ operation: @MainActor (WorkspaceModel, URL) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-app-workspace-tests-\(UUID().uuidString)")
    let suiteName = "LocalTodoAppTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    let model = WorkspaceModel(
        bookmarks: VaultBookmarkStore(defaults: defaults),
        taskListDisplayPreferences: TaskListDisplayPreferencesStore(defaults: defaults)
    )
    await model.createVault(at: root)
    #expect(model.errorMessage == nil)
    try await operation(model, root)
}

@MainActor
func waitForHistory(_ model: WorkspaceModel) async throws {
    for _ in 0 ..< 100 where model.isHistoryBusy {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(!model.isHistoryBusy)
}
