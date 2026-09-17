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
    let session = model.vaultSession
    #expect(model.moveCollections(from: IndexSet(integer: 0), to: 2, in: .area, paths: areas, session: session))
    #expect(!model.moveCollections(from: IndexSet(integer: 0), to: 2, in: .project, paths: areas, session: session))
    let restored = WorkspaceModel(bookmarks: bookmarks, sidebarPreferences: defaults)
    await restored.restoreVault()
    #expect(restored.orderedCollectionPaths(.project) == Array(projects.reversed()))
    #expect(restored.orderedCollectionPaths(.area) == Array(areas.reversed()))
    #expect(!restored.moveCollections(
        from: IndexSet(integer: 0), to: 2, in: .area,
        paths: restored.orderedCollectionPaths(.area), session: session
    ))
    restored.resetSidebarOrder(.project)
    #expect(restored.orderedCollectionPaths(.project) == projects)
    #expect(restored.orderedCollectionPaths(.area) == Array(areas.reversed()))
    #expect(try Data(contentsOf: root.appendingPathComponent(projects[1].value)) == bytes)
}

@MainActor
@Test func nativeProjectMovesSupportBothEndsAndRejectStaleOrder() async throws {
    try await withWorkspace { model, _ in
        for name in ["a", "b", "c"] {
            await model.createCollection(kind: .project, path: "Projects/\(name).md", title: name)
        }
        let paths = model.orderedCollectionPaths(.project)
        let session = model.vaultSession
        #expect(model.moveCollections(from: IndexSet(integer: 0), to: 3, in: .project, paths: paths, session: session))
        #expect(model.orderedCollectionPaths(.project) == [paths[1], paths[2], paths[0]])
        #expect(!model.moveCollections(from: IndexSet(integer: 0), to: 2, in: .project, paths: paths, session: session))
        let reordered = model.orderedCollectionPaths(.project)
        #expect(model.moveCollections(
            from: IndexSet(integer: 2),
            to: 0,
            in: .project,
            paths: reordered,
            session: session
        ))
        #expect(model.orderedCollectionPaths(.project) == paths)
        #expect(!model.moveCollections(from: IndexSet(integer: 3), to: 0, in: .project, paths: paths, session: session))
        #expect(!model.moveCollections(from: IndexSet(integer: 0), to: 4, in: .project, paths: paths, session: session))
        #expect(model.orderedCollectionPaths(.project) == paths)
    }
}
