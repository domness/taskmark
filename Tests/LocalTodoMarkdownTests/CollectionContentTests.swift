import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func collectionContentRestorationRefusesOccupiedDestination() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let record = try await store.create(.project(project))
    let data = try await store.entityContent(at: project.path, expectedRevision: record.revision)
    _ = try await store.delete(at: project.path, expectedRevision: record.revision)
    let url = root.appendingPathComponent(project.path.value)
    let occupied = Data("User-owned malformed Markdown".utf8)
    try occupied.write(to: url)
    await #expect(throws: VaultStoreError.self) {
        try await store.restoreEntityContent(data, at: project.path)
    }
    #expect(try Data(contentsOf: url) == occupied)
}

@Test func savedFilterReferencePreventsCollectionDeletion() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let record = try await store.create(.project(project))
    var query = TaskQuery()
    query.filters.project = project.path
    _ = try await store.saveFilters([SavedTaskFilter(name: "Project", query: query)], expectedRevision: nil)
    await #expect(throws: VaultStoreError.self) {
        try await store.delete(at: project.path, expectedRevision: record.revision)
    }
    #expect(try await store.snapshot().projects[project.path] != nil)
}
