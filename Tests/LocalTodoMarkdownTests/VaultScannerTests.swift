import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func scannerIndexesEntitiesAndReportsReferences() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let missingProject = try VaultPath("Projects/Missing.md")
    _ = try await store.create(.task(testTask(path: "Tasks/Test.md", project: missingProject)))

    let snapshot = try await store.snapshot()

    #expect(snapshot.tasks.count == 1)
    #expect(snapshot.diagnostics.count == 1)
    #expect(snapshot.diagnostics.first?.kind == .referenceMissing)
    #expect(snapshot.diagnostics.first?.reference == missingProject)
}

@Test func scannerSurfacesMalformedFrontmatter() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let malformed = try fixture(named: "malformed-yaml")
    try malformed.write(to: root.appendingPathComponent("Tasks/Bad.md"), atomically: true, encoding: .utf8)

    let snapshot = try await VaultStore(root: root).snapshot()

    #expect(snapshot.tasks.isEmpty)
    #expect(snapshot.diagnostics.first?.kind == .frontmatterMalformed)
    #expect(snapshot.diagnostics.first?.path?.value == "Tasks/Bad.md")
}

@Test func scannerIgnoresOrdinaryMarkdown() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    try "# Notes\n".write(to: root.appendingPathComponent("Notes.md"), atomically: true, encoding: .utf8)

    let snapshot = try await VaultStore(root: root).snapshot()

    #expect(snapshot.tasks.isEmpty)
    #expect(snapshot.diagnostics.isEmpty)
}
