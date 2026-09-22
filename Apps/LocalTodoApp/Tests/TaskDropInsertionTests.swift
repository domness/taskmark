import Foundation
@testable import LocalTodoApp
import Testing

@MainActor
struct TaskDropInsertionTests {
    @Test func rowProviderRemainsCompatibleWithSidebarTransferable() async throws {
        let original = TaskDragItem(path: "Tasks/Test.md", vaultSession: UUID())
        let decoded: TaskDragItem = try await withCheckedThrowingContinuation { continuation in
            _ = original.itemProvider().loadTransferable(type: TaskDragItem.self) { result in
                continuation.resume(with: result)
            }
        }
        #expect(decoded.path == original.path)
        #expect(decoded.vaultSession == original.vaultSession)
    }

    @Test func insertAtEndAndBeginningWithoutSelectingSource() async throws {
        try await withWorkspace { model, _ in
            model.route = .inbox
            for title in ["First", "Second", "Third"] {
                await model.createTask(title: title, vaultSession: model.vaultSession)
            }
            model.setTaskListSort(.custom)
            model.selectTask(nil)
            let context = model.taskReorderContext(for: model.visibleTasks)
            let item = try TaskDragItem(
                path: #require(context.sectionPaths.first).value,
                vaultSession: model.vaultSession, reorder: TaskDragOrder(context: context)
            )
            #expect(model.insertDraggedTask(item, at: 3, context: context))
            #expect(model.visibleTasks.map(\.title) == ["Second", "Third", "First"])
            #expect(model.selectedTaskPath == nil)
            #expect(!model.insertDraggedTask(item, at: 0, context: context), "Reject stale source order")
            let updated = model.taskReorderContext(for: model.visibleTasks)
            let returning = TaskDragItem(
                path: item.path, vaultSession: model.vaultSession, reorder: TaskDragOrder(context: updated)
            )
            #expect(model.insertDraggedTask(returning, at: 0, context: updated))
            #expect(model.visibleTasks.map(\.title) == ["First", "Second", "Third"])
        }
    }

    @Test func rejectForeignAndNonReorderDrags() async throws {
        try await withWorkspace { model, _ in
            model.route = .inbox
            for title in ["First", "Second"] {
                await model.createTask(title: title, vaultSession: model.vaultSession)
            }
            model.setTaskListSort(.custom)
            let context = model.taskReorderContext(for: model.visibleTasks)
            let path = try #require(context.sectionPaths.first).value
            let foreign = TaskDragItem(path: path, vaultSession: UUID(), reorder: TaskDragOrder(context: context))
            #expect(!model.insertDraggedTask(foreign, at: 2, context: context))
            let automatic = TaskDragItem(path: path, vaultSession: model.vaultSession)
            #expect(!model.insertDraggedTask(automatic, at: 2, context: context))
            let valid = TaskDragItem(
                path: path, vaultSession: model.vaultSession, reorder: TaskDragOrder(context: context)
            )
            model.setTaskListSort(.automatic(.title))
            #expect(!model.insertDraggedTask(valid, at: 2, context: context))
        }
    }
}
