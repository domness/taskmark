import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func projectEditingAutosavesAndPreservesIdentityAndReferences() async throws {
    try await withWorkspace { model, root in
        let draft = try await makeProjectDraft(model)
        let url = root.appendingPathComponent(draft.path.value)
        let source = try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "type: project", with: "type: project\nplugin: [keep, this]")
        try Data(source.utf8).write(to: url)
        await model.refresh()
        let task = try TodoTask(
            path: VaultPath("Tasks/Linked.md"),
            title: "Linked",
            status: .next,
            project: draft.path,
            createdAt: Date(),
            updatedAt: Date()
        )
        _ = try await VaultStore(root: root).create(.task(task))
        let taskURL = root.appendingPathComponent(task.path.value)
        let taskBytes = try Data(contentsOf: taskURL)
        draft.title = "Renamed display title"
        draft.notes = "# Notes 🦊\r\n\r\n- [x] Existing note\r\n"
        model.route = .today
        try await Task.sleep(for: .milliseconds(750))
        let saved = try #require(try await VaultStore(root: root).snapshot().projects[draft.path]?.value)
        #expect(saved.title == draft.title)
        #expect(saved.body == draft.notes)
        #expect(saved.path.value == "Projects/Original.md")
        #expect(try Data(contentsOf: taskURL) == taskBytes)
        #expect(try MarkdownDocument.parse(String(contentsOf: url, encoding: .utf8)).strings(forKey: "plugin") == [
            "keep",
            "this",
        ])
        #expect(!draft.isDirty)
    }
}

@MainActor
@Test func projectCompletionReopeningAndHistoryPreserveNotes() async throws {
    try await withWorkspace { model, root in
        let draft = try await makeProjectDraft(model)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        model.toggleProjectCompletion(draft)
        undo.endUndoGrouping()
        #expect(await model.flushTaskChanges())
        #expect(model.activeProjects.isEmpty)
        #expect(model.inactiveProjects.map(\.path) == [draft.path])
        #expect(try await VaultStore(root: root).snapshot().projects[draft.path]?.value.completedAt != nil)
        draft.notes = "Written after completion"
        #expect(await model.flushTaskChanges())
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(draft.status == .active)
        #expect(draft.notes == "Written after completion")
        #expect(model.activeProjects.count == 1)
        #expect(try await VaultStore(root: root).snapshot().projects[draft.path]?.value.completedAt == nil)
        model.performRedo()
        #expect(await model.flushTaskChanges())
        #expect(draft.status == .done)
        undo.beginUndoGrouping()
        model.toggleProjectCompletion(draft)
        undo.endUndoGrouping()
        #expect(await model.flushTaskChanges())
        #expect(model.inactiveProjects.isEmpty)
        #expect(try await VaultStore(root: root).snapshot().projects[draft.path]?.value.status == .active)
    }
}

@MainActor
@Test(arguments: [ProjectStatus.someday, .done, .canceled])
func inactiveProjectsStayAvailableAfterReload(status: ProjectStatus) async throws {
    try await withWorkspace { model, root in
        let draft = try await makeProjectDraft(model)
        draft.status = status
        #expect(await model.flushTaskChanges())
        let suiteName = "ProjectReloadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let bookmarks = VaultBookmarkStore(defaults: defaults)
        try bookmarks.save(root)
        let reloaded = WorkspaceModel(bookmarks: bookmarks)
        await reloaded.restoreVault()
        #expect(reloaded.activeProjects.isEmpty)
        #expect(reloaded.inactiveProjects.map(\.path) == [draft.path])
        reloaded.route = .project(draft.path)
        #expect(reloaded.selectedProjectDraft?.status == status)
        #expect(reloaded.errorMessage == nil)
    }
}

@MainActor
func makeProjectDraft(_ model: WorkspaceModel) async throws -> ProjectDraft {
    await model.createCollection(kind: .project, path: "Projects/Original.md", title: "Original")
    model.route = try .project(VaultPath("Projects/Original.md"))
    return try #require(model.selectedProjectDraft)
}
