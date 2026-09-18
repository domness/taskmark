import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func recurringCompletionFailureKeepsDatesAndChecklistForRetry() async throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z"))
    try await withWorkspace(now: now) { model, root in
        await model.createTask(title: "Repeat safely", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.recurrence = try .afterCompletion(RecurrenceInterval(value: 3, unit: .day))
        draft.resetChecklistOnRepeat = true
        draft.notes = "Notes\r\n- [X] Done\r\n"
        draft.scheduled = "2026-09-01"
        draft.deadline = "2026-09-04"
        #expect(await model.flushTaskChanges())
        let url = root.appendingPathComponent(draft.path.value)
        let original = try Data(contentsOf: url)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        model.store = VaultStore(root: root, fileSystem: WriteRejectingFileSystem())
        await model.completeSelectedTask()
        #expect(try Data(contentsOf: url) == original)
        #expect(!undo.canUndo)
        model.store = VaultStore(root: root)
        undo.beginUndoGrouping()
        await model.completeSelectedTask()
        undo.endUndoGrouping()
        let saved = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        #expect(saved.scheduled?.description == "2026-09-19")
        #expect(saved.deadline?.description == "2026-09-22")
        #expect(saved.body == "Notes\r\n- [ ] Done\r\n")
        try await withReloadedWorkspace(root, now: now) { reloaded in
            reloaded.selectTask(draft.path)
            #expect(reloaded.selectedTaskDraft?.recurrence == saved.recurrence)
            #expect(reloaded.selectedTaskDraft?.resetChecklistOnRepeat == true)
            #expect(reloaded.selectedTaskDraft?.notes == saved.body)
        }
    }
}

@MainActor
@Test func rescheduleUndoRetainsPlanningConflictDependencies() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Plan", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.scheduled = "2026-09-16"
        #expect(await model.flushTaskChanges())
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        try model.rescheduleTask(at: draft.path, to: CalendarDate("2026-09-18"), session: model.vaultSession)
        #expect(await model.flushTaskChanges())
        model.performUndo()
        let store = VaultStore(root: root)
        let record = try #require(try await store.snapshot().tasks[draft.path])
        var patch = TaskPatch()
        patch.status = .set(.done)
        _ = try await store.update(
            .task(patch.applying(to: record.value, now: Date())),
            expectedRevision: record.revision
        )
        let url = root.appendingPathComponent(draft.path.value)
        let bytes = try Data(contentsOf: url)
        await model.updateTask(draft)
        #expect(draft.hasConflicts)
        #expect(try Data(contentsOf: url) == bytes)
        model.discardChanges(for: draft.path)
    }
}

@MainActor
@Test func clearingAppFilterCriteriaSurvivesWorkspaceReload() async throws {
    try await withWorkspace { model, root in
        let project = try await makeProjectDraft(model)
        model.beginFilterEditing()
        model.filterState.name = "Editable"
        model.filterState.editor.project = project.path.value
        model.filterState.editor.scheduledFrom = "2026-09-01"
        model.filterState.editor.text = "old text"
        await model.saveWorkingFilter()
        model.beginFilterEditing(name: "Editable")
        model.filterState.editor.project = ""
        model.filterState.editor.scheduledFrom = ""
        model.filterState.editor.text = ""
        await model.saveWorkingFilter()
        try await withReloadedWorkspace(root) { reloaded in
            reloaded.beginFilterEditing(name: "Editable")
            #expect(reloaded.filterState.editor.project.isEmpty)
            #expect(reloaded.filterState.editor.scheduledFrom.isEmpty)
            #expect(reloaded.filterState.editor.text.isEmpty)
        }
    }
}

@MainActor
@Test func sortingPreferencesPersistInTheVault() async throws {
    try await withWorkspace { model, root in
        model.route = .today
        model.setTaskListMetadata(.project, isVisible: false)
        #expect(model.currentTaskSort == .priority)
        model.setTaskSort(.deadline)
        #expect(await model.flushPreferences())
        let reloaded = WorkspaceModel()
        let opened = try await reloaded.openVault(root)
        #expect(opened)
        reloaded.route = .today
        #expect(reloaded.currentTaskSort == .deadline)
        #expect(!reloaded.currentTaskListDisplayOptions.showsProject)
        reloaded.route = .upcoming
        #expect(reloaded.currentTaskSort == .scheduled)
    }
}
