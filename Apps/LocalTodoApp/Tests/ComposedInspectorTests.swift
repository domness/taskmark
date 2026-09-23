import AppKit
@testable import LocalTodoApp
import LocalTodoDomain
import SwiftUI
import Testing

@MainActor
struct ComposedInspectorTests {
    @Test func completionUsesPendingDraftAndCanReopen() async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "Review the proposal", vaultSession: model.vaultSession)
            let draft = try #require(model.selectedTaskDraft)
            draft.status = .next
            #expect(await model.flushTaskChanges())
            let window = inspectorWindow(model: model, draft: draft)
            defer { window.close() }
            try await presentForNativeInput(window)
            draft.notes = "Keep this unsaved note when completing."
            try await pressCompletion(in: window)
            try await waitForNativeUI("inspector completion saved", in: window) {
                draft.status == .done && !draft.isDirty
            }
            #expect(model.snapshot?.tasks[draft.path]?.value.body == draft.notes)
            #expect(draft.sourceTask.completedAt != nil)
            try await pressCompletion(in: window)
            try await waitForNativeUI("inspector reopening saved", in: window) {
                draft.status == .next && !draft.isDirty
            }
            #expect(draft.sourceTask.completedAt == nil)
        }
    }

    @Test func inspectorCompletionAdvancesRecurringDraftOnlyOnce() async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "Repeat review", vaultSession: model.vaultSession)
            let draft = try #require(model.selectedTaskDraft)
            draft.scheduled = "2099-01-01"
            draft.recurrence = try .afterCompletion(RecurrenceInterval(value: 3, unit: .day))
            draft.resetChecklistOnRepeat = true
            draft.notes = "- [x] Review\n"
            #expect(await model.flushTaskChanges())
            let window = inspectorWindow(model: model, draft: draft)
            defer { window.close() }
            try await presentForNativeInput(window)
            try await pressCompletion(in: window)
            try await waitForNativeUI("inspector repeat completion", in: window) {
                draft.scheduled != "2099-01-01" && !draft.isDirty
            }
            #expect(!draft.status.isComplete)
            #expect(draft.notes == "- [ ] Review\n")
            let expected = try CalendarDate(date: model.clock(), calendar: model.vaultCalendar)
                .adding(DateComponents(day: 3), calendar: model.vaultCalendar)
            #expect(draft.scheduled == expected.description)
        }
    }

    @Test func completionDoesNotDiscardAnInvalidDraft() async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "Keep my draft", vaultSession: model.vaultSession)
            let draft = try #require(model.selectedTaskDraft)
            let window = inspectorWindow(model: model, draft: draft)
            defer { window.close() }
            try await presentForNativeInput(window)
            draft.title = ""
            try await pressCompletion(in: window)
            try await waitForNativeUI("pending draft blocks completion", in: window) {
                model.errorMessage != nil
            }
            #expect(draft.title.isEmpty)
            #expect(draft.isDirty)
            #expect(model.snapshot?.tasks[draft.path]?.value.status == .inbox)
            draft.title = "Keep my draft"
            #expect(await model.flushTaskChanges())
        }
    }

    private func inspectorWindow(model: WorkspaceModel, draft: TaskDraft) -> NSWindow {
        let controller = NSHostingController(rootView: TaskInspectorHeader(
            model: model, draft: draft, isTitleEditing: .constant(false)
        )
        .padding()
        .modifier(AppAppearanceModifier(model: model)))
        let window = NSWindow(contentViewController: controller)
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 340, height: 160))
        return window
    }

    private func pressCompletion(in window: NSWindow) async throws {
        try await waitForNativeUI("enabled completion button", in: window) {
            completionButton(in: window.contentView)?.isEnabled == true
        }
        let control = try #require(completionButton(in: window.contentView))
        control.performClick(nil)
    }

    private func completionButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        return (view as? NSButton) ?? view.subviews.lazy.compactMap { completionButton(in: $0) }.first
    }
}
