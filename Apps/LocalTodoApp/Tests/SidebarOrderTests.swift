import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import Testing

@MainActor
@Test func sidebarOrderingPersistsIndependentlyAndRejectsStaleDrags() async throws {
    let suite = "SidebarOrderTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
    defer {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
    let bookmarks = VaultBookmarkStore(defaults: defaults)
    let model = WorkspaceModel(bookmarks: bookmarks, sidebarPreferences: defaults)
    await model.createVault(at: root)
    for name in ["a", "b"] {
        await model.createCollection(kind: .project, path: "Projects/\(name).md", title: name)
        await model.createCollection(kind: .area, path: "Areas/\(name).md", title: name)
    }
    let projects = model.orderedCollectionPaths(.project)
    let areas = model.orderedCollectionPaths(.area)
    #expect(projects.count == 2)
    #expect(areas.count == 2)
    let bytes = try Data(contentsOf: root.appendingPathComponent(projects[1].value))
    model.moveCollection(projects[1], in: .project, offset: -1)
    #expect(model.orderedCollectionPaths(.project) == Array(projects.reversed()))
    #expect(model.orderedCollectionPaths(.area) == areas)
    let item = CollectionDragItem(path: areas[1].value, collection: .area, session: model.vaultSession)
    #expect(model.reorderCollection(item, before: areas[0], in: .area))
    #expect(!model.reorderCollection(item, before: projects[0], in: .project))
    let restored = WorkspaceModel(bookmarks: bookmarks, sidebarPreferences: defaults)
    await restored.restoreVault()
    #expect(restored.orderedCollectionPaths(.project) == Array(projects.reversed()))
    #expect(restored.orderedCollectionPaths(.area) == Array(areas.reversed()))
    #expect(!restored.reorderCollection(item, before: areas[0], in: .area))
    restored.resetSidebarOrder(.project)
    #expect(restored.orderedCollectionPaths(.project) == projects)
    #expect(restored.orderedCollectionPaths(.area) == Array(areas.reversed()))
    #expect(try Data(contentsOf: root.appendingPathComponent(projects[1].value)) == bytes)
}
