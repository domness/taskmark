import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func checklistTogglePersistsAcrossSelectionWithUndoRedo() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Steps", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "Notes 🦊\r\n- [ ] First\r\n  * [X] Second\r\n"
        #expect(await model.flushTaskChanges())
        let original = draft.notes
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        let projection = MarkdownChecklist(draft.notes)
        undo.beginUndoGrouping()
        try model.setChecklistItem(#require(projection.items.first), checked: true, in: draft, projection: projection)
        undo.endUndoGrouping()
        model.selectTask(nil)
        try await Task.sleep(for: .milliseconds(750))
        let checked = original.replacingOccurrences(of: "[ ] First", with: "[x] First")
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.body == checked)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.body == original)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.body == checked)
    }
}

@MainActor
@Test func checklistToggleRejectsStaleProjectionAndConflictsWithExternalNotes() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Steps", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.notes = "- [ ] First\n"
        #expect(await model.flushTaskChanges())
        let projection = MarkdownChecklist(draft.notes)
        let item = try #require(projection.items.first)
        draft.notes = "New prefix\n" + draft.notes
        model.setChecklistItem(item, checked: true, in: draft, projection: projection)
        #expect(draft.notes == "New prefix\n- [ ] First\n")
        #expect(model.errorMessage != nil)
        model.discardChanges(for: draft.path)
        model.setChecklistItem(item, checked: true, in: draft, projection: projection)
        let store = VaultStore(root: root)
        let record = try #require(try await store.snapshot().tasks[draft.path])
        var patch = TaskPatch()
        patch.body = .set("External notes\n- [ ] First\n")
        _ = try await store.update(
            .task(patch.applying(to: record.value, now: Date())),
            expectedRevision: record.revision
        )
        await model.updateTask(draft)
        #expect(draft.conflictedFields.contains(.notes))
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value
            .body == "External notes\n- [ ] First\n")
        model.discardChanges(for: draft.path)
    }
}
