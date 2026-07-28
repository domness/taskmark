import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func workspaceAssignsTaskToProjectAndAreaWithoutClearingEither() async throws {
    try await withWorkspace { model, _ in
        await model.createCollection(kind: .project, path: "Projects/Launch.md", title: "Launch")
        await model.createCollection(kind: .area, path: "Areas/Work.md", title: "Work")
        await model.createTask(title: "Organize me", vaultSession: model.vaultSession)
        let taskPath = try #require(model.snapshot?.tasks.keys.first)
        let projectPath = try VaultPath("Projects/Launch.md")
        let areaPath = try VaultPath("Areas/Work.md")
        model.selectTask(taskPath)
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "Keep these notes"
        draft.tags = "launch, work"
        draft.scheduled = "2026-08-03"
        await model.updateTask(draft)

        await model.assignTask(at: taskPath, toProject: projectPath, vaultSession: UUID())
        #expect(model.snapshot?.tasks[taskPath]?.value.project == nil)
        await model.assignTask(at: taskPath, toProject: projectPath, vaultSession: model.vaultSession)
        let undoManager = UndoManager()
        model.setUndoManager(undoManager)
        let assignedRevision = model.snapshot?.tasks[taskPath]?.revision
        await model.assignTask(at: taskPath, toProject: projectPath, vaultSession: model.vaultSession)
        #expect(model.snapshot?.tasks[taskPath]?.revision == assignedRevision)
        #expect(!undoManager.canUndo)
        await model.assignTask(at: taskPath, toArea: areaPath, vaultSession: model.vaultSession)

        let organized = try #require(model.snapshot?.tasks[taskPath]?.value)
        #expect(organized.project == projectPath)
        #expect(organized.area == areaPath)
        #expect(organized.body == "Keep these notes")
        #expect(organized.tags == ["launch", "work"])
        #expect(organized.scheduled?.description == "2026-08-03")

        model.performUndo()
        try await Task.sleep(for: .milliseconds(700))

        let undone = try #require(model.snapshot?.tasks[taskPath]?.value)
        #expect(undone.project == projectPath)
        #expect(undone.area == nil)
    }
}

@MainActor
@Test func workspaceDoesNotRetryAConflictedAssignmentOrRegisterUndo() async throws {
    try await withWorkspace { model, root in
        await model.createCollection(kind: .project, path: "Projects/Launch.md", title: "Launch")
        await model.createTask(title: "Organize me", vaultSession: model.vaultSession)
        let taskPath = try #require(model.snapshot?.tasks.keys.first)
        let projectPath = try VaultPath("Projects/Launch.md")
        model.selectTask(taskPath)
        let draft = try #require(model.selectedTaskDraft)
        let undoManager = UndoManager()
        model.setUndoManager(undoManager)

        let externalStore = VaultStore(root: root)
        let externalRecord = try #require(try await externalStore.snapshot().tasks[taskPath])
        var patch = TaskPatch()
        patch.title = .set("Changed externally")
        let externalTask = try patch.applying(to: externalRecord.value, now: Date())
        _ = try await externalStore.update(.task(externalTask), expectedRevision: externalRecord.revision)

        await model.assignTask(at: taskPath, toProject: projectPath, vaultSession: model.vaultSession)
        try await Task.sleep(for: .milliseconds(700))

        let stored = try #require(try await externalStore.snapshot().tasks[taskPath]?.value)
        #expect(stored.title == "Changed externally")
        #expect(stored.project == nil)
        #expect(draft.project.isEmpty)
        #expect(!draft.isDirty)
        #expect(!undoManager.canUndo)
    }
}

@MainActor
@Test func taskListDisplayOptionsPersistIndependentlyPerView() throws {
    let suiteName = "LocalTodoAppListPreferencesTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = TaskListDisplayPreferencesStore(defaults: defaults)
    let model = WorkspaceModel(
        bookmarks: VaultBookmarkStore(defaults: defaults),
        taskListDisplayPreferences: preferences
    )
    model.route = .today

    model.setTaskListMetadata(.project, isVisible: false)
    model.setTaskListGrouping(.project)

    #expect(!model.currentTaskListDisplayOptions.showsProject)
    #expect(model.currentTaskListDisplayOptions.grouping == .project)
    model.route = .inbox
    #expect(model.currentTaskListDisplayOptions.showsProject)
    #expect(model.currentTaskListDisplayOptions.grouping == .none)

    let restored = WorkspaceModel(
        bookmarks: VaultBookmarkStore(defaults: defaults),
        taskListDisplayPreferences: preferences
    )
    restored.route = .today
    #expect(!restored.currentTaskListDisplayOptions.showsProject)
    #expect(restored.currentTaskListDisplayOptions.grouping == .project)
}
