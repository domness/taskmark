import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func repeatEditingAutosavesAcrossSelectionAndReload() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Repeat", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        let fixed = try TaskRecurrence.fixed(FixedRecurrenceRule(
            frequency: .weekly, interval: 2, weekdays: [.monday, .friday]
        ))
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        model.changeDraft(draft, keyPath: \.recurrence, to: fixed, actionName: "Change Repeat")
        model.changeDraft(draft, keyPath: \.resetChecklistOnRepeat, to: true, actionName: "Change Reset")
        undo.endUndoGrouping()
        model.selectTask(nil)
        try await Task.sleep(for: .milliseconds(750))
        let saved = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        #expect(saved.recurrence == fixed)
        #expect(saved.resetChecklistOnRepeat)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.recurrence == nil)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.recurrence == fixed)
        var editor = RecurrenceEditorValue(fixed)
        editor.mode = .afterCompletion
        editor.unit = .month
        draft.recurrence = try editor.recurrence()
        #expect(await model.flushTaskChanges())
        let after = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        #expect(try after.recurrence == .afterCompletion(RecurrenceInterval(value: 2, unit: .month)))
        draft.recurrence = nil
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.recurrence == nil)
    }
}

@MainActor
@Test(arguments: [false, true])
func completionUsesPendingRepeatEdits(inspector: Bool) async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Pending repeat", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.recurrence = try .afterCompletion(RecurrenceInterval(value: 3, unit: .day))
        draft.resetChecklistOnRepeat = true
        draft.notes = "Notes\r\n- [X] Done\r\n"
        draft.scheduled = "2026-01-01"
        if inspector {
            model.changeTaskStatus(draft, to: .done)
        } else {
            await model.completeTask(at: draft.path, expectedRevision: draft.revision, vaultSession: model.vaultSession)
        }
        #expect(await model.flushTaskChanges())
        let saved = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        let today = try CalendarDate(date: Date(), calendar: model.vaultCalendar)
        #expect(saved.status == .next)
        #expect(try saved.scheduled == today.adding(DateComponents(day: 3), calendar: model.vaultCalendar))
        #expect(saved.body == "Notes\r\n- [ ] Done\r\n")
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func externalRepeatEditConflictsWithoutOverwriting() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Conflict", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.recurrence = try .fixed(FixedRecurrenceRule(frequency: .weekly))
        let store = VaultStore(root: root)
        let record = try #require(try await store.snapshot().tasks[draft.path])
        var patch = TaskPatch()
        patch.recurrence = try .set(.afterCompletion(RecurrenceInterval(value: 2, unit: .day)))
        _ = try await store.update(
            .task(patch.applying(to: record.value, now: Date())),
            expectedRevision: record.revision
        )
        await model.updateTask(draft)
        #expect(draft.conflictedFields.contains(.recurrence))
        #expect(try await store.snapshot().tasks[draft.path]?.value.recurrence != draft.recurrence)
        draft.resolveConflictsKeepingLocalChanges()
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.recurrence == draft.recurrence)
    }
}

@Test func recurrenceEditorRoundTripsAndRejectsInvalidIntervals() throws {
    let values: [TaskRecurrence?] = try [
        nil, .fixed(FixedRecurrenceRule(frequency: .weekly, interval: 3, weekdays: [.tuesday, .saturday])),
        .afterCompletion(RecurrenceInterval(value: 8, unit: .week)),
    ]
    for value in values {
        #expect(try RecurrenceEditorValue(value).recurrence() == value)
    }
    var editor = RecurrenceEditorValue(nil)
    editor.mode = .fixed
    editor.interval = 0
    #expect(throws: DomainValidationError.invalidRecurrenceRule) { try editor.recurrence() }
}
