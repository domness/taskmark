import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test(arguments: [WorkspaceRoute.upcoming, .waiting, .someday])
func dailyViewsSupportCaptureCompletionAndReload(route: WorkspaceRoute) async throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z"))
    try await withWorkspace(now: now) { model, root in
        model.route = route
        model.beginQuickCapture()
        #expect(model.quickCaptureRoute == route)
        await model.createTask(
            title: "Daily task",
            vaultSession: model.vaultSession,
            captureRoute: model.quickCaptureRoute
        )
        let path = try #require(model.selectedTaskPath)
        #expect(model.visibleTasks.map(\.path) == [path])
        try await withReloadedWorkspace(root, now: now) { reloaded in
            reloaded.route = route
            #expect(reloaded.visibleTasks.map(\.path) == [path])
            reloaded.selectTask(path)
            let undo = UndoManager()
            undo.groupsByEvent = false
            reloaded.setUndoManager(undo)
            undo.beginUndoGrouping()
            await reloaded.completeSelectedTask()
            undo.endUndoGrouping()
            #expect(reloaded.visibleTasks.isEmpty)
            #expect(try await VaultStore(root: root).snapshot().tasks[path]?.value.status == .done)
            reloaded.performUndo()
            try await waitForHistory(reloaded)
            #expect(reloaded.visibleTasks.map(\.path) == [path])
            reloaded.performRedo()
            try await waitForHistory(reloaded)
            #expect(reloaded.visibleTasks.isEmpty)
        }
    }
}

@MainActor
@Test(arguments: [WorkspaceRoute.upcoming, .waiting, .someday])
func dailyReschedulingUsesSharedOffsetsAndNativeHistory(route: WorkspaceRoute) async throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z"))
    try await withWorkspace(now: now) { model, root in
        await model.createTask(title: "Move dates", vaultSession: model.vaultSession, captureRoute: route)
        let draft = try #require(model.selectedTaskDraft)
        draft.scheduled = "2026-09-17"
        draft.deadline = "2026-09-20"
        draft.notes = "Notes\r\n- [X] Keep\r\n"
        #expect(await model.flushTaskChanges())
        model.route = route
        model.selectTask(draft.path)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        model.beginRescheduling()
        #expect(model.rescheduleSelection?.path == draft.path)
        model.rescheduleSelectedTask(daysFromToday: 0)
        #expect(await model.flushTaskChanges())
        let saved = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
        #expect(saved.scheduled?.description == "2026-09-16")
        #expect(saved.deadline?.description == "2026-09-19")
        #expect(saved.body == draft.notes)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(draft.scheduled == "2026-09-17")
        #expect(draft.deadline == "2026-09-20")
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(draft.scheduled == "2026-09-16")
        #expect(draft.deadline == "2026-09-19")
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func captureContextSurvivesNavigationAndRescheduleRejectsStaleSession() async throws {
    try await withWorkspace { model, root in
        model.route = .waiting
        model.beginQuickCapture()
        model.route = .today
        await model.createTask(
            title: "Waiting capture",
            vaultSession: model.vaultSession,
            captureRoute: model.quickCaptureRoute
        )
        let draft = try #require(model.selectedTaskDraft)
        #expect(draft.status == .waiting)
        let bytes = try Data(contentsOf: root.appendingPathComponent(draft.path.value))
        #expect(try !model.rescheduleTask(at: draft.path, to: CalendarDate("2026-09-16"), session: UUID()))
        #expect(!draft.isDirty)
        #expect(try Data(contentsOf: root.appendingPathComponent(draft.path.value)) == bytes)
    }
}
