import Foundation
@testable import LocalTodoApp
import LocalTodoMarkdown
import Testing

@MainActor
@Test func tagTokensPreserveCommasAndSupportUndo() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Tags", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        #expect(model.addTag(" #Design, research ", to: draft))
        #expect(model.addTag("Design, research", to: draft))
        #expect(!model.addTag(" # ", to: draft))
        undo.endUndoGrouping()
        #expect(draft.tags == ["Design, research"])
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.tags == ["Design, research"])
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(draft.tags.isEmpty)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(draft.tags == ["Design, research"])
        draft.title = "Renamed"
        #expect(await model.flushTaskChanges())
        #expect(draft.tags == ["Design, research"])
    }
}
