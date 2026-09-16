import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func appCombinesSavesAndReloadsFiltersWithSorting() async throws {
    try await withWorkspace { model, root in
        let project = try await makeProjectDraft(model)
        try await seedFilterTasks(root: root, project: project.path)
        await model.refresh()
        model.beginFilterEditing()
        model.filterState.editor.project = project.path.value
        model.filterState.editor.statuses = [.waiting, .next]
        model.filterState.editor.priorities = [.p1, .p2]
        model.filterState.editor.tags = "work, desk"
        model.filterState.editor.text = "review"
        model.filterState.editor.scheduledFrom = "2026-09-18"
        model.filterState.editor.scheduledThrough = "2026-09-18"
        model.filterState.editor.deadlineThrough = "2026-09-20"
        model.filterState.name = "Desk reviews"
        #expect(model.visibleTasks.map(\.title) == ["Review B", "Review A"])
        await model.saveWorkingFilter()
        #expect(model.route == .savedFilter("Desk reviews"))
        #expect(model.filterState.saveError == nil)
        let saved = try #require(try await VaultStore(root: root).savedFilters().filters.first)
        #expect(saved.query == model.currentTaskQuery)
        try await withReloadedWorkspace(root) { reloaded in
            reloaded.route = .savedFilter("Desk reviews")
            #expect(reloaded.visibleTasks.map(\.title) == ["Review B", "Review A"])
            reloaded.setTaskSort(.title)
            #expect(reloaded.route == .filters)
            #expect(reloaded.visibleTasks.map(\.title) == ["Review A", "Review B"])
            await reloaded.saveWorkingFilter()
            let updated = try await VaultStore(root: root).savedFilters()
            #expect(updated.filters.first?.query.sort == .title)
        }
    }
}

@MainActor
@Test func savingFiltersSupportsUndoRedoWithoutChangingTaskFiles() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Keep", vaultSession: model.vaultSession)
        let path = try #require(model.selectedTaskPath)
        let taskBytes = try Data(contentsOf: root.appendingPathComponent(path.value))
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        model.beginFilterEditing()
        model.filterState.name = "Saved"
        model.filterState.editor.statuses = [.inbox]
        undo.beginUndoGrouping()
        await model.saveWorkingFilter()
        undo.endUndoGrouping()
        model.performUndo()
        try await waitForHistory(model)
        #expect(try await VaultStore(root: root).savedFilters().filters.isEmpty)
        model.performRedo()
        try await waitForHistory(model)
        #expect(try await VaultStore(root: root).savedFilters().filters.first?.name == "Saved")
        #expect(try Data(contentsOf: root.appendingPathComponent(path.value)) == taskBytes)
    }
}

@MainActor
@Test func invalidOrDuplicateFiltersAreNotSaved() async throws {
    try await withWorkspace { model, root in
        model.beginFilterEditing()
        model.filterState.name = "Dates"
        model.filterState.editor.scheduledFrom = "2026-09-20"
        model.filterState.editor.scheduledThrough = "2026-09-01"
        #expect(model.filterState.editor.validationMessage != nil)
        #expect(model.visibleTasks.isEmpty)
        await model.saveWorkingFilter()
        let invalid = try await VaultStore(root: root).savedFilters()
        #expect(invalid.filters.isEmpty)
        model.filterState.editor.scheduledThrough = "2026-09-30"
        await model.saveWorkingFilter()
        model.beginFilterEditing()
        model.filterState.name = "Dates"
        await model.saveWorkingFilter()
        #expect(model.filterState.saveError?.contains("already exists") == true)
        #expect(try await VaultStore(root: root).savedFilters().filters.count == 1)
    }
}

@MainActor
func withReloadedWorkspace(
    _ root: URL, now: Date? = nil, operation: (WorkspaceModel) async throws -> Void
) async throws {
    let suite = "ReloadedWorkspace.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let bookmarks = VaultBookmarkStore(defaults: defaults)
    try bookmarks.save(root)
    let model = WorkspaceModel(
        bookmarks: bookmarks,
        taskListDisplayPreferences: TaskListDisplayPreferencesStore(defaults: defaults),
        clock: { now ?? Date() }
    )
    await model.restoreVault()
    #expect(model.errorMessage == nil)
    try await operation(model)
}

private func seedFilterTasks(root: URL, project: VaultPath) async throws {
    let store = VaultStore(root: root)
    for (name, priority, tags) in [
        ("A", TaskPriority.p2, ["work", "desk"]),
        ("B", .p1, ["work", "desk"]),
        ("C", .p1, ["work"]),
    ] {
        let task = try TodoTask(
            path: VaultPath("Tasks/\(name).md"), title: "Review \(name)", status: .waiting, priority: priority,
            scheduled: CalendarDate("2026-09-18"), deadline: CalendarDate("2026-09-20"), project: project,
            tags: tags, createdAt: Date(), updatedAt: Date()
        )
        _ = try await store.create(.task(task))
    }
}
