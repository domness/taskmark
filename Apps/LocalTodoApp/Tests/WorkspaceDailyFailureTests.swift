import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

enum TaskWriteWorkflow: CaseIterable {
    case recurrence, checklist, reschedule
}

@MainActor
@Test(arguments: TaskWriteWorkflow.allCases)
func dailyTaskWriteFailuresRetainOriginalBytesAndRetry(workflow: TaskWriteWorkflow) async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Atomic", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "Notes\r\n- [ ] First\r\n"
        draft.scheduled = "2026-09-16"
        draft.deadline = "2026-09-20"
        #expect(await model.flushTaskChanges())
        let url = root.appendingPathComponent(draft.path.value)
        let bytes = try Data(contentsOf: url)
        model.store = VaultStore(root: root, fileSystem: WriteRejectingFileSystem())
        switch workflow {
        case .recurrence:
            draft.recurrence = try .fixed(FixedRecurrenceRule(frequency: .weekly, weekdays: [.monday]))
            draft.resetChecklistOnRepeat = true
        case .checklist:
            let checklist = MarkdownChecklist(draft.notes)
            try model.setChecklistItem(#require(checklist.items.first), checked: true, in: draft, projection: checklist)
        case .reschedule:
            try model.rescheduleTask(at: draft.path, to: CalendarDate("2026-09-18"), session: model.vaultSession)
        }
        #expect(await !(model.flushTaskChanges()))
        #expect(draft.isDirty)
        #expect(try Data(contentsOf: url) == bytes)
        let expected = try draft.patch().applying(to: draft.sourceTask, now: Date())
        model.store = VaultStore(root: root)
        #expect(await model.flushTaskChanges())
        let saved = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        #expect(saved.body == expected.body)
        #expect(saved.scheduled == expected.scheduled)
        #expect(saved.deadline == expected.deadline)
        #expect(saved.recurrence == expected.recurrence)
        #expect(saved.resetChecklistOnRepeat == expected.resetChecklistOnRepeat)
    }
}

@MainActor
@Test(arguments: [false, true])
func reschedulingConflictsWithChangedPlanningInputs(changeStatus: Bool) async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Plan", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.scheduled = "2026-09-16"
        #expect(await model.flushTaskChanges())
        try model.rescheduleTask(at: draft.path, to: CalendarDate("2026-09-18"), session: model.vaultSession)
        let store = VaultStore(root: root)
        let record = try #require(try await store.snapshot().tasks[draft.path])
        var patch = TaskPatch()
        if changeStatus {
            patch.status = .set(.done)
        } else {
            patch.deadline = try .set(CalendarDate("2026-09-20"))
        }
        _ = try await store.update(
            .task(patch.applying(to: record.value, now: Date())),
            expectedRevision: record.revision
        )
        let bytes = try Data(contentsOf: root.appendingPathComponent(draft.path.value))
        await model.updateTask(draft)
        #expect(draft.hasConflicts)
        #expect(try Data(contentsOf: root.appendingPathComponent(draft.path.value)) == bytes)
        model.discardChanges(for: draft.path)
    }
}

@MainActor
@Test func failedCaptureKeepsTextAndCreatesNoTask() async throws {
    try await withWorkspace { model, root in
        model.route = .waiting
        model.beginQuickCapture()
        model.quickCaptureTitle = "Retry capture"
        model.store = VaultStore(root: root, fileSystem: WriteRejectingFileSystem())
        await model.createTask(
            title: model.quickCaptureTitle,
            vaultSession: model.vaultSession,
            captureRoute: model.quickCaptureRoute
        )
        #expect(model.quickCaptureTitle == "Retry capture")
        #expect(model.isQuickCapturePresented)
        let snapshot = try await VaultStore(root: root).snapshot()
        #expect(snapshot.tasks.isEmpty)
        model.store = VaultStore(root: root)
        await model.createTask(
            title: model.quickCaptureTitle,
            vaultSession: model.vaultSession,
            captureRoute: model.quickCaptureRoute
        )
        #expect(model.visibleTasks.first?.status == .waiting)
        #expect(model.quickCaptureTitle.isEmpty)
    }
}
