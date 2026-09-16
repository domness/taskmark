import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test(arguments: [false, true])
func inspectorCompletionRollsRecurringTaskForward(afterCompletion: Bool) async throws {
    try await withWorkspace { model, root in
        let draft = try await recurringDraft(model: model, root: root, afterCompletion: afterCompletion)
        draft.title = "Edited title"
        draft.notes = "Local notes\n- [x] Keep checked\n"
        draft.scheduled = "2026-07-02"
        draft.deadline = "2026-07-05"
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-27T23:30:00Z"))
        // The vault is in Tokyo, where this instant is July 28.
        let before = try draft.patch().applying(to: draft.sourceTask, now: now)
        let expected = try TaskTransition.complete(
            before, now: now, today: CalendarDate("2026-07-28"), calendar: model.vaultCalendar
        )

        model.changeTaskStatus(draft, to: .done, now: now)
        #expect(await model.flushTaskChanges())

        let saved = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        #expect(saved.status == .next)
        #expect(saved.scheduled == expected.scheduled)
        #expect(saved.deadline == expected.deadline)
        #expect(saved.completedAt == nil)
        #expect(saved.title == "Edited title")
        #expect(saved.body == "Local notes\n- [x] Keep checked\n")
        #expect(!draft.isDirty)
        #expect(model.errorMessage == nil)
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value == saved)
    }
}

@MainActor
@Test func inspectorRecurringCompletionUndoesAndRedoesDatesTogether() async throws {
    try await withWorkspace { model, root in
        let draft = try await recurringDraft(model: model, root: root)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-27T12:00:00Z"))

        model.changeTaskStatus(draft, to: .done, now: now)
        #expect(await model.flushTaskChanges())
        let completed = try #require(model.snapshot?.tasks[draft.path]?.value)
        draft.notes = "Written after completing"
        #expect(await model.flushTaskChanges())
        model.performUndo()
        #expect(await model.flushTaskChanges())

        #expect(draft.status == .waiting)
        #expect(draft.scheduled == "2026-07-01")
        #expect(draft.deadline == "2026-07-04")
        #expect(draft.notes == "Written after completing")
        #expect(undo.canRedo)

        model.performRedo()
        #expect(await model.flushTaskChanges())
        let redone = try #require(model.snapshot?.tasks[draft.path]?.value)
        #expect(redone.status == .next)
        #expect(redone.scheduled == completed.scheduled)
        #expect(redone.deadline == completed.deadline)
        #expect(redone.body == "Written after completing")
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func inspectorRejectsRecurringCompletionWithInvalidDraft() async throws {
    try await withWorkspace { model, root in
        let draft = try await recurringDraft(model: model, root: root)
        draft.scheduled = "not-a-date"

        model.changeTaskStatus(draft, to: .done)

        #expect(draft.status == .waiting)
        #expect(draft.scheduled == "not-a-date")
        #expect(draft.deadline == "2026-07-04")
        #expect(model.errorMessage != nil)
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.status == .waiting)
        model.discardChanges(for: draft.path)
    }
}

@MainActor
private func recurringDraft(
    model: WorkspaceModel, root: URL, afterCompletion: Bool = false
) async throws -> TaskDraft {
    let configuration = VaultConfiguration(timezone: "Asia/Tokyo")
    try Data(configuration.encoded().utf8).write(to: root.appendingPathComponent(LocalTodoSchema.manifestPath))
    let recurrence: TaskRecurrence = try afterCompletion
        ? .afterCompletion(RecurrenceInterval(value: 3, unit: .day))
        : .fixed(FixedRecurrenceRule(frequency: .weekly))
    let task = try TodoTask(
        path: VaultPath("Tasks/Recurring.md"), title: "Recurring", status: .waiting,
        scheduled: CalendarDate("2026-07-01"), deadline: CalendarDate("2026-07-04"),
        recurrence: recurrence, createdAt: Date(), updatedAt: Date()
    )
    _ = try await VaultStore(root: root).create(.task(task))
    await model.refresh()
    model.selectTask(task.path)
    return try #require(model.selectedTaskDraft)
}

@MainActor
@Test func inspectorStatusChangesKeepNonRecurringBehavior() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "One-off", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.scheduled = "2026-07-01"
        model.changeTaskStatus(draft, to: .done)
        #expect(await model.flushTaskChanges())
        let saved = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        #expect(saved.status == .done)
        #expect(saved.completedAt != nil)
        #expect(saved.scheduled?.description == "2026-07-01")

        model.changeTaskStatus(draft, to: .waiting)
        #expect(await model.flushTaskChanges())
        #expect(model.snapshot?.tasks[draft.path]?.value.status == .waiting)
        #expect(model.snapshot?.tasks[draft.path]?.value.completedAt == nil)
        #expect(draft.scheduled == "2026-07-01")
    }
}

@MainActor
@Test func inspectorRecurringCompletionRetryDoesNotAdvanceTwice() async throws {
    try await withWorkspace { model, root in
        let draft = try await recurringDraft(model: model, root: root)
        model.changeTaskStatus(draft, to: .done)
        let expectedScheduled = draft.scheduled
        let expectedDeadline = draft.deadline
        let store = VaultStore(root: root)
        let record = try #require(try await store.snapshot().tasks[draft.path])
        var patch = TaskPatch()
        patch.body = .set("External notes\n- [x] Keep\n")
        let external = try patch.applying(to: record.value, now: Date())
        _ = try await store.update(.task(external), expectedRevision: record.revision)

        await model.updateTask(draft)

        #expect(!draft.hasConflicts)
        #expect(!draft.isDirty)
        #expect(draft.scheduled == expectedScheduled)
        #expect(draft.deadline == expectedDeadline)
        #expect(draft.status == .next)
        #expect(draft.notes == external.body)
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func inspectorRecurringCompletionKeepsExternalDateConflicts() async throws {
    try await withWorkspace { model, root in
        let draft = try await recurringDraft(model: model, root: root)
        model.changeTaskStatus(draft, to: .done)
        let store = VaultStore(root: root)
        let record = try #require(try await store.snapshot().tasks[draft.path])
        var patch = TaskPatch()
        patch.scheduled = try .set(CalendarDate("2026-09-01"))
        let external = try patch.applying(to: record.value, now: Date())
        _ = try await store.update(.task(external), expectedRevision: record.revision)
        let url = root.appendingPathComponent(draft.path.value)
        let externalBytes = try Data(contentsOf: url)

        await model.updateTask(draft)

        #expect(draft.conflictedFields.contains(.scheduled))
        #expect(try Data(contentsOf: url) == externalBytes)
        let conflictedDate = draft.scheduled
        model.changeTaskStatus(draft, to: .done)
        #expect(draft.conflictedFields.contains(.scheduled))
        #expect(draft.scheduled == conflictedDate)
        #expect(model.errorMessage != nil)
        model.discardChanges(for: draft.path)
    }
}

@MainActor
@Test(arguments: [false, true])
func inspectorRecurringCompletionConflictsWithChangedInputs(changeRecurrence: Bool) async throws {
    try await withWorkspace { model, root in
        let draft = try await recurringDraft(model: model, root: root)
        let store = VaultStore(root: root)
        var record = try #require(try await store.snapshot().tasks[draft.path])
        var patch = TaskPatch()
        patch.status = .set(.next)
        _ = try await store.update(
            .task(patch.applying(to: record.value, now: Date())), expectedRevision: record.revision
        )
        await model.refresh()
        model.changeTaskStatus(draft, to: .done)
        record = try #require(try await store.snapshot().tasks[draft.path])
        patch = TaskPatch()
        if changeRecurrence {
            patch.recurrence = .set(nil)
        } else {
            patch.status = .set(.canceled)
        }
        _ = try await store.update(
            .task(patch.applying(to: record.value, now: Date())), expectedRevision: record.revision
        )
        let url = root.appendingPathComponent(draft.path.value)
        let externalBytes = try Data(contentsOf: url)

        await model.updateTask(draft)

        #expect(draft.hasConflicts)
        #expect(try Data(contentsOf: url) == externalBytes)
        model.discardChanges(for: draft.path)
    }
}
