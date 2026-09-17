import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func customTaskOrderMovesBothDirectionsAndSurvivesReload() async throws {
    try await withWorkspace { model, root in
        let paths = try await createOrderTasks(model)
        let original = try paths.map { try Data(contentsOf: root.appendingPathComponent($0.value)) }
        model.setTaskListSort(.custom)
        #expect(move(model, from: [0], to: 3))
        #expect(model.visibleTasks.map(\.path) == [paths[1], paths[2], paths[0]])
        #expect(move(model, from: [2], to: 0))
        #expect(model.visibleTasks.map(\.path) == paths)
        #expect(move(model, from: [0, 1], to: 3))
        let expected = [paths[2], paths[0], paths[1]]
        let reloaded = WorkspaceModel(
            bookmarks: VaultBookmarkStore(defaults: model.sidebarPreferences),
            sidebarPreferences: model.sidebarPreferences
        )
        await reloaded.restoreVault()
        reloaded.route = .inbox
        #expect(reloaded.currentTaskListSort == .custom)
        #expect(reloaded.visibleTasks.map(\.path) == expected)
        model.setTaskSort(.title)
        #expect(model.visibleTasks.map(\.path) == paths)
        #expect(!move(model, from: [0], to: 3))
        model.setTaskListSort(.custom)
        #expect(model.visibleTasks.map(\.path) == expected)
        #expect(try paths.map { try Data(contentsOf: root.appendingPathComponent($0.value)) } == original)
    }
}

@MainActor
@Test func customTaskOrdersStaySeparateByRouteAndVault() async throws {
    try await withWorkspace { model, root in
        let paths = try await createOrderTasks(model)
        model.setTaskListSort(.custom)
        #expect(move(model, from: [0], to: 3))
        model.route = .all
        #expect(!model.isCustomTaskOrder)
        model.setTaskListSort(.custom)
        #expect(move(model, from: [2], to: 0))
        #expect(model.visibleTasks.map(\.path) == [paths[2], paths[0], paths[1]])
        model.route = .inbox
        #expect(model.visibleTasks.map(\.path) == [paths[1], paths[2], paths[0]])
        let otherRoot = root.appendingPathComponent("OtherVault")
        await model.createVault(at: otherRoot)
        _ = try await createOrderTasks(model)
        #expect(!model.isCustomTaskOrder)
        #expect(model.visibleTasks.map(\.path) == paths)
    }
}

@MainActor
@Test func customMovesRejectStaleRoutesSessionsSectionsAndIndices() async throws {
    try await withWorkspace { model, _ in
        _ = try await createOrderTasks(model)
        model.setTaskListSort(.custom)
        let context = model.taskReorderContext(for: model.visibleTasks)
        #expect(!move(model, from: [3], to: 0))
        #expect(!move(model, from: [0], to: 4))
        #expect(!move(model, from: [], to: 0))
        #expect(!move(model, from: [0], to: 1))
        model.route = .all
        model.setTaskListSort(.custom)
        #expect(!model.moveTasks(from: [0], to: 3, context: context))
        model.route = .inbox
        model.setTaskListGrouping(.area)
        #expect(!model.moveTasks(from: [0], to: 3, context: context))
        model.setTaskListGrouping(.none)
        #expect(move(model, from: [0], to: 3))
        #expect(!model.moveTasks(from: [0], to: 3, context: context))
        let reloaded = WorkspaceModel(
            bookmarks: VaultBookmarkStore(defaults: model.sidebarPreferences),
            sidebarPreferences: model.sidebarPreferences
        )
        await reloaded.restoreVault()
        reloaded.route = .inbox
        #expect(!reloaded.moveTasks(from: [0], to: 3, context: model.taskReorderContext(for: model.visibleTasks)))
    }
}

@MainActor
@Test func customGroupedMovesPreserveOtherGroupsAndNewTasksAppend() async throws {
    try await withWorkspace { model, _ in
        let paths = try await createOrderTasks(model)
        await model.createCollection(kind: .project, path: "Projects/Work.md", title: "Work")
        model.selectTask(paths[1])
        let draft = try #require(model.selectedTaskDraft)
        draft.project = "Projects/Work.md"
        #expect(await model.flushTaskChanges())
        model.route = .inbox
        model.setTaskListSort(.custom)
        model.setTaskListGrouping(.project)
        let tasks = model.visibleTasks.filter { $0.project == nil }
        #expect(model.moveTasks(from: [0], to: 2, context: model.taskReorderContext(for: tasks)))
        #expect(model.visibleTasks.map(\.path) == [paths[2], paths[1], paths[0]])
        let mixed = model.taskReorderContext(for: model.visibleTasks)
        #expect(!model.moveTasks(from: [0], to: 3, context: mixed))
        model.setTaskListGrouping(.none)
        await model.createTask(title: "0 New", vaultSession: model.vaultSession)
        #expect(model.visibleTasks.prefix(3).map(\.path) == [paths[2], paths[1], paths[0]])
        #expect(model.visibleTasks.last?.title == "0 New")
    }
}

@MainActor
@Test func customSearchMovesRetainHiddenPositions() async throws {
    try await withWorkspace { model, _ in
        _ = try await createOrderTasks(model)
        model.route = .search
        model.searchText = "Task"
        model.setTaskListSort(.custom)
        model.searchText = "Match"
        #expect(move(model, from: [0], to: 2))
        model.searchText = "Task"
        #expect(model.visibleTasks.map(\.title) == ["C Task Match", "B Task", "A Task Match"])
    }
}

@MainActor
@Test func customSavedFilterOrderDoesNotRewriteCanonicalFilter() async throws {
    try await withWorkspace { model, root in
        _ = try await createOrderTasks(model)
        let store = VaultStore(root: root)
        _ = try await store.saveFilters(
            [SavedTaskFilter(name: "Work", query: TaskQuery(sort: .title))],
            expectedRevision: nil
        )
        await model.refreshSavedFilters()
        let url = root.appendingPathComponent(VaultStore.savedFiltersPath)
        let bytes = try Data(contentsOf: url)
        model.route = .savedFilter("Work")
        model.setTaskListSort(.custom)
        #expect(move(model, from: [0], to: 3))
        #expect(model.route == .savedFilter("Work"))
        #expect(try Data(contentsOf: url) == bytes)
        model.setTaskSort(.deadline)
        #expect(model.route == .filters)
        #expect(model.currentTaskListSort == .automatic(.deadline))
    }
}

@MainActor
private func createOrderTasks(_ model: WorkspaceModel) async throws -> [VaultPath] {
    model.route = .inbox
    for title in ["A Task Match", "B Task", "C Task Match"] {
        await model.createTask(title: title, vaultSession: model.vaultSession)
    }
    #expect(model.visibleTasks.count == 3)
    return model.visibleTasks.map(\.path)
}

@MainActor
private func move(_ model: WorkspaceModel, from offsets: IndexSet, to destination: Int) -> Bool {
    model.moveTasks(from: offsets, to: destination, context: model.taskReorderContext(for: model.visibleTasks))
}
