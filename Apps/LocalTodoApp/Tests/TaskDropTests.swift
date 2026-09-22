import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
struct TaskDropTests {
    @Test func appDeclaresItsTaskDragType() throws {
        let declarations = try #require(
            Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations") as? [[String: Any]]
        )
        #expect(declarations.contains {
            $0["UTTypeIdentifier"] as? String == "com.domness.localtodo.task-reference"
                && ($0["UTTypeConformsTo"] as? [String])?.contains("public.data") == true
        })
    }

    @Test(arguments: [false, true])
    func sidebarDropsPreserveContentAndSupportUndo(custom: Bool) async throws {
        try await withWorkspace { model, root in
            await model.createCollection(kind: .project, path: "Projects/Launch.md", title: "Launch")
            await model.createCollection(kind: .area, path: "Areas/Work.md", title: "Work")
            await model.createTask(title: "Source", vaultSession: model.vaultSession)
            let donor = try #require(model.selectedTaskDraft)
            donor.tags = ["work, home"]
            #expect(await model.flushTaskChanges())
            await model.createTask(title: "Target", vaultSession: model.vaultSession)
            let draft = try #require(model.selectedTaskDraft)
            draft.tags = ["existing"]
            draft.notes = "Keep **Markdown**\n- [x] Step\n"
            #expect(await model.flushTaskChanges())
            model.setTaskListSort(custom ? .custom : .automatic(.title))
            let item = TaskDragItem(path: draft.path.value, vaultSession: model.vaultSession)
            let project = try VaultPath("Projects/Launch.md")
            let area = try VaultPath("Areas/Work.md")
            await model.applyTaskDrop([item], onto: .project(project))
            await model.applyTaskDrop([item], onto: .area(area))
            let undoManager = UndoManager()
            model.setUndoManager(undoManager)
            await model.applyTaskDrop([item], onto: .tag("work, home"))
            #expect(draft.tags == ["existing", "work, home"])
            #expect(!draft.isDirty)
            #expect(undoManager.undoActionName == "Add Tag")
            let revision = model.snapshot?.tasks[draft.path]?.revision
            await model.applyTaskDrop([item], onto: .tag("work, home"))
            #expect(model.snapshot?.tasks[draft.path]?.revision == revision)

            model.performUndo()
            try await waitForHistory(model)
            #expect(draft.tags == ["existing"])
            #expect(!undoManager.canUndo)
            model.performRedo()
            try await waitForHistory(model)
            let stored = try #require(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value)
            #expect(stored.tags == ["existing", "work, home"])
            #expect(stored.project == project)
            #expect(stored.area == area)
            #expect(stored.body == "Keep **Markdown**\n- [x] Step\n")
        }
    }

    @Test func dropsRejectInvalidStaleAndMultipleReferences() async throws {
        try await withWorkspace { model, _ in
            await model.createCollection(kind: .project, path: "Projects/Launch.md", title: "Launch")
            await model.createTask(title: "Task", vaultSession: model.vaultSession)
            let path = try #require(model.selectedTaskPath)
            let item = TaskDragItem(path: path.value, vaultSession: model.vaultSession)
            let project = try SidebarAssignmentTarget.project(VaultPath("Projects/Launch.md"))
            for items in [
                [], [item, item],
                [TaskDragItem(path: path.value, vaultSession: UUID())],
                [TaskDragItem(path: "../outside.md", vaultSession: model.vaultSession)],
                [TaskDragItem(path: "Tasks/Missing.md", vaultSession: model.vaultSession)],
            ] {
                #expect(model.taskDropPath(items, onto: project) == nil)
                await model.applyTaskDrop(items, onto: project)
            }
            #expect(model.snapshot?.tasks[path]?.value.project == nil)
            #expect(model.taskDropPath([item], onto: .tag("missing")) == nil)
            #expect(try model.taskDropPath([item], onto: .area(VaultPath("Areas/Missing.md"))) == nil)
            #expect(model.taskDropPath([item], onto: project) == path)
        }
    }

    @Test func failedTagDropDoesNotRetryOrRegisterHistory() async throws {
        try await withWorkspace { model, root in
            await model.createTask(title: "Source", vaultSession: model.vaultSession)
            let donor = try #require(model.selectedTaskDraft)
            donor.tags = ["work"]
            #expect(await model.flushTaskChanges())
            await model.createTask(title: "Target", vaultSession: model.vaultSession)
            let draft = try #require(model.selectedTaskDraft)
            let undoManager = UndoManager()
            model.setUndoManager(undoManager)
            let store = VaultStore(root: root)
            let record = try #require(try await store.snapshot().tasks[draft.path])
            var patch = TaskPatch()
            patch.body = .set("External notes")
            _ = try await store.update(
                .task(patch.applying(to: record.value, now: Date())), expectedRevision: record.revision
            )
            await model.applyTaskDrop(
                [TaskDragItem(path: draft.path.value, vaultSession: model.vaultSession)], onto: .tag("work")
            )
            #expect(await model.flushTaskChanges())
            let stored = try #require(try await store.snapshot().tasks[draft.path]?.value)
            #expect(stored.tags.isEmpty)
            #expect(stored.body == "External notes")
            #expect(!draft.isDirty)
            #expect(!undoManager.canUndo)
            #expect(model.errorMessage != nil)
        }
    }

    private func waitForHistory(_ model: WorkspaceModel) async throws {
        for _ in 0 ..< 200 where model.isHistoryBusy {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!model.isHistoryBusy)
    }
}
