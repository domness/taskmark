import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test(arguments: [NewEntityKind.project, .area])
func collectionDeletionRestoresExactBytes(kind: NewEntityKind) async throws {
    try await withWorkspace { model, root in
        let path = try VaultPath("Collections/Example.md")
        await model.createCollection(kind: kind, path: path.value, title: "Example")
        let url = root.appendingPathComponent(path.value)
        let original = try String(contentsOf: url, encoding: .utf8)
        try original.replacingOccurrences(of: "title: Example", with: "title: Example\ncustom: [one, two]")
            .appending("Notes 🦊\r\n").write(to: url, atomically: true, encoding: .utf8)
        await model.refresh()
        let bytes = try Data(contentsOf: url)
        model.route = kind == .project ? .project(path) : .area(path)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        await model.deleteCollection(at: path)
        undo.endUndoGrouping()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(model.route == .inbox)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(try Data(contentsOf: url) == bytes)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func deletingProjectSavesPendingNotesForUndo() async throws {
    try await withWorkspace { model, _ in
        let draft = try await makeProjectDraft(model)
        draft.notes = "Pending notes"
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        await model.deleteCollection(at: draft.path)
        undo.endUndoGrouping()
        #expect(model.snapshot?.projects[draft.path] == nil)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(model.snapshot?.projects[draft.path]?.value.body == "Pending notes")
    }
}

@MainActor
@Test(arguments: [NewEntityKind.project, .area])
func referencedCollectionDeletionLeavesFilesIntact(kind: NewEntityKind) async throws {
    try await withWorkspace { model, root in
        let path = try VaultPath("Collections/Example.md")
        await model.createCollection(kind: kind, path: path.value, title: "Example")
        await model.createTask(title: "Assigned", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        if kind == .project {
            draft.project = path.value
        } else {
            draft.area = path.value
        }
        #expect(await model.flushTaskChanges())
        let url = root.appendingPathComponent(path.value)
        let bytes = try Data(contentsOf: url)
        await model.deleteCollection(at: path)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(model.errorMessage?.contains("Remove those references first") == true)
    }
}

@MainActor
@Test func staleCollectionDeletePreservesExternalNotes() async throws {
    try await withWorkspace { model, root in
        let draft = try await makeProjectDraft(model)
        let url = root.appendingPathComponent(draft.path.value)
        var bytes = try Data(contentsOf: url)
        bytes.append(Data("External notes".utf8))
        try bytes.write(to: url)
        await model.deleteCollection(at: draft.path)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(model.errorMessage != nil)
    }
}
