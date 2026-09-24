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
@Test(arguments: [NewEntityKind.project, .area], [TaskStatus.next, .done, .canceled])
func referencedCollectionDeletionClearsAssignmentsAndSupportsUndo(
    kind: NewEntityKind,
    status: TaskStatus
) async throws {
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
        model.changeTaskStatus(draft, to: status)
        #expect(await model.flushTaskChanges())
        let url = root.appendingPathComponent(path.value)
        let bytes = try Data(contentsOf: url)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        await model.deleteCollection(at: path)
        undo.endUndoGrouping()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let task = try #require(model.snapshot?.tasks[draft.path]?.value)
        #expect(task.project == nil && task.area == nil)
        #expect(task.status == status)
        #expect(!draft.isDirty)
        #expect(draft.project.isEmpty && draft.area.isEmpty)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(try Data(contentsOf: url) == bytes)
        let restored = try #require(model.snapshot?.tasks[draft.path]?.value)
        #expect(kind == .project ? restored.project == path : restored.area == path)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(model.snapshot?.tasks[draft.path]?.value.project == nil)
        #expect(model.snapshot?.tasks[draft.path]?.value.area == nil)
        #expect(model.errorMessage == nil)
    }
}

@MainActor
@Test func deletingTagFlushesDraftAndRestoresSavedFilterWithUndo() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Tagged", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.tags = ["remove", "keep"]
        #expect(await model.flushTaskChanges())
        var query = TaskQuery()
        query.filters.tags = ["remove", "keep"]
        let filter = try SavedTaskFilter(name: "Tagged", query: query)
        _ = try await VaultStore(root: root).saveFilters([filter], expectedRevision: nil)
        await model.refresh()
        draft.notes = "Pending notes"
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        model.route = .tag("remove")
        undo.beginUndoGrouping()
        await model.deleteTag("remove")
        undo.endUndoGrouping()
        #expect(model.route == .inbox)
        #expect(draft.tags == ["keep"] && draft.notes == "Pending notes")
        #expect(model.filterState.record?.filters.first?.query.filters.tags == ["keep"])
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(draft.tags == ["remove", "keep"])
        #expect(model.filterState.record?.filters == [filter])
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(draft.tags == ["keep"])
        #expect(model.errorMessage == nil)
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
