import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func workspaceCanRecreateAnExternallyDeletedDirtyTask() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Original", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.title = "Recovered"
        let externalStore = VaultStore(root: root)
        let externalRecord = try #require(try await externalStore.snapshot().tasks[path])
        _ = try await externalStore.delete(at: path, expectedRevision: externalRecord.revision)

        await model.refresh()

        #expect(draft.sourceUnavailableMessage != nil)
        #expect(draft.canRecreateSource)
        #expect(draft.isDirty)
        let undoManager = UndoManager()
        model.setUndoManager(undoManager)
        await model.recreateTask(draft)

        #expect(draft.sourceUnavailableMessage == nil)
        #expect(!draft.isDirty)
        #expect(try await externalStore.snapshot().tasks[path]?.value.title == "Recovered")
        #expect(undoManager.canUndo)

        model.performUndo()
        try await waitForHistory(model)
        #expect(try await externalStore.snapshot().tasks[path] == nil)
    }
}

@MainActor
@Test func workspaceSavesCopyWhenUnavailablePathIsOccupied() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Original", vaultSession: model.vaultSession)
        let path = try #require(model.snapshot?.tasks.keys.first)
        model.selectTask(path)
        let draft = try #require(model.selectedTaskDraft)
        draft.title = "Recovered copy"
        let externalStore = VaultStore(root: root)
        let externalRecord = try #require(try await externalStore.snapshot().tasks[path])
        _ = try await externalStore.delete(at: path, expectedRevision: externalRecord.revision)
        let timestamp = Date(timeIntervalSince1970: 1_774_608_000)
        let replacement = try Project(
            path: path,
            title: "External project",
            status: .active,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        _ = try await externalStore.create(.project(replacement))

        await model.refresh()

        #expect(draft.sourceUnavailableMessage != nil)
        #expect(!draft.canRecreateSource)
        let undoManager = UndoManager()
        model.setUndoManager(undoManager)
        await model.saveTaskCopy(draft)

        let copyPath = try #require(model.selectedTaskPath)
        let copiedDraft = try #require(model.selectedTaskDraft)
        var saved = try await externalStore.snapshot()
        #expect(saved.projects[path]?.value.title == "External project")
        #expect(saved.tasks[copyPath]?.value.title == "Recovered copy")

        copiedDraft.notes = "Typed before autosave"
        model.performUndo()
        #expect(undoManager.canUndo)
        #expect(try await externalStore.snapshot().tasks[copyPath] != nil)

        try await Task.sleep(for: .milliseconds(700))
        model.performUndo()
        try await waitForHistory(model)

        saved = try await externalStore.snapshot()
        #expect(saved.projects[path]?.value.title == "External project")
        #expect(saved.tasks[copyPath] == nil)
    }
}
