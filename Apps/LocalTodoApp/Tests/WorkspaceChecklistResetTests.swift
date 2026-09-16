import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test(arguments: [false, true])
func repeatingChecklistCompletionPersistsAndUndoes(inspector: Bool) async throws {
    try await withWorkspace { model, root in
        let task = try resetTask()
        _ = try await VaultStore(root: root).create(.task(task))
        await model.refresh()
        model.selectTask(task.path)
        let draft = try #require(model.selectedTaskDraft)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        if inspector {
            model.changeTaskStatus(draft, to: .done)
            #expect(await model.flushTaskChanges())
        } else {
            undo.beginUndoGrouping()
            await model.completeTask(
                at: task.path, expectedRevision: draft.revision, vaultSession: model.vaultSession
            )
            undo.endUndoGrouping()
        }
        let completed = try #require(try await VaultStore(root: root).snapshot().tasks[task.path]?.value)
        #expect(completed.body == "Notes\r\n- [ ] Done\r\n- [ ] Pending\r\n")
        #expect(completed.resetChecklistOnRepeat)
        model.performUndo()
        try await waitForHistory(model)
        #expect(await model.flushTaskChanges())
        let undone = try #require(try await VaultStore(root: root).snapshot().tasks[task.path]?.value)
        #expect(undone.body == task.body)
        #expect(undone.scheduled == task.scheduled)
        model.performRedo()
        try await waitForHistory(model)
        #expect(await model.flushTaskChanges())
        let redone = try #require(try await VaultStore(root: root).snapshot().tasks[task.path]?.value)
        #expect(redone.body == completed.body)
        #expect(redone.scheduled == completed.scheduled)
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test(arguments: [false, true])
func checklistResetConflictsWithExternalNotesOrPreference(changePreference: Bool) async throws {
    try await withWorkspace { model, root in
        let task = try resetTask()
        let store = VaultStore(root: root)
        _ = try await store.create(.task(task))
        await model.refresh()
        model.selectTask(task.path)
        let draft = try #require(model.selectedTaskDraft)
        model.changeTaskStatus(draft, to: .done)
        let record = try #require(try await store.snapshot().tasks[task.path])
        var patch = TaskPatch()
        if changePreference {
            patch.resetChecklistOnRepeat = .set(false)
        } else {
            patch.body = .set("External notes\n- [x] Keep")
        }
        _ = try await store.update(
            .task(patch.applying(to: record.value, now: Date())), expectedRevision: record.revision
        )
        let url = root.appendingPathComponent(task.path.value)
        let bytes = try Data(contentsOf: url)
        await model.updateTask(draft)
        #expect(draft.hasConflicts)
        #expect(try Data(contentsOf: url) == bytes)
        model.discardChanges(for: task.path)
    }
}

private func resetTask() throws -> TodoTask {
    try TodoTask(
        path: VaultPath("Tasks/Reset.md"), title: "Reset", status: .next,
        scheduled: CalendarDate("2026-07-01"),
        recurrence: .afterCompletion(RecurrenceInterval(value: 1, unit: .day)),
        resetChecklistOnRepeat: true,
        body: "Notes\r\n- [X] Done\r\n- [ ] Pending\r\n", createdAt: Date(), updatedAt: Date()
    )
}
