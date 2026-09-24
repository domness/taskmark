import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func interruptedOrganizationRemovalRetainsCollectionAndCanUndoOrRetry() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let record = try await store.create(.project(project))
    for name in ["A", "B"] {
        _ = try await store.create(.task(testTask(path: "Tasks/\(name).md", project: project.path)))
    }
    let failing = VaultStore(
        root: root, fileSystem: FailingWriteFileSystem(base: FoundationVaultFileSystem(), failureWrite: 2)
    )
    let changes = try await failing.planOrganizationRemoval(.project(project.path), expectedRevision: record.revision)
    let result = await failing.applyOrganizationChanges(changes, now: Date())
    #expect(result.errorMessage?.contains("stopped after 1 change") == true)
    let snapshot = try await store.snapshot()
    #expect(snapshot.projects[project.path] != nil)
    #expect(snapshot.tasks.values.filter { $0.value.project == project.path }.count == 1)
    #expect(await store.applyOrganizationChanges(result.undo, now: Date()).errorMessage == nil)
    #expect(try await store.snapshot().tasks.values.allSatisfy { $0.value.project == project.path })
    let retry = try await store.planOrganizationRemoval(.project(project.path), expectedRevision: record.revision)
    #expect(await store.applyOrganizationChanges(retry, now: Date()).errorMessage == nil)
    #expect(try await store.snapshot().projects.isEmpty)
}

@Test func organizationRemovalRejectsChangedAssignmentsButPreservesUnrelatedExternalEdits() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let record = try await store.create(.project(project))
    let task = try testTask(path: "Tasks/Test.md", project: project.path)
    let created = try await store.create(.task(task))
    let changes = try await store.planOrganizationRemoval(.project(project.path), expectedRevision: record.revision)
    var patch = TaskPatch()
    patch.title = .set("External title")
    _ = try await store.update(.task(patch.applying(to: task, now: Date())), expectedRevision: created.revision)
    let result = await store.applyOrganizationChanges(changes, now: Date())
    #expect(result.errorMessage == nil)
    #expect(try await store.snapshot().tasks[task.path]?.value.title == "External title")
    let current = try #require(try await store.snapshot().tasks[task.path])
    let other = try testProject(path: "Projects/Other.md")
    _ = try await store.create(.project(other))
    patch = TaskPatch()
    patch.project = .set(other.path)
    _ = try await store.update(
        .task(patch.applying(to: current.value, now: Date())),
        expectedRevision: current.revision
    )
    let undo = await store.applyOrganizationChanges(result.undo, now: Date())
    #expect(undo.errorMessage != nil)
    #expect(try await store.snapshot().tasks[task.path]?.value.project == other.path)
    #expect(try await store.snapshot().projects[project.path] != nil)
}

@Test func malformedFilePreventsOrganizationCleanupBeforeAnyWrites() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let record = try await store.create(.project(project))
    let task = try testTask(path: "Tasks/Test.md", project: project.path)
    let created = try await store.create(.task(task))
    try "---\ntype: task\ntitle: [broken\n---\n".write(
        to: root.appendingPathComponent("Tasks/Broken.md"), atomically: true, encoding: .utf8
    )
    await #expect(throws: VaultStoreError.self) {
        try await store.planOrganizationRemoval(.project(project.path), expectedRevision: record.revision)
    }
    #expect(try await store.snapshot().tasks[task.path]?.revision == created.revision)
    #expect(try await store.snapshot().projects[project.path]?.revision == record.revision)
}

@Test func organizationUndoRefusesOccupiedCollectionBeforeRestoringReferences() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let record = try await store.create(.project(project))
    let task = try testTask(path: "Tasks/Test.md", project: project.path)
    _ = try await store.create(.task(task))
    let changes = try await store.planOrganizationRemoval(.project(project.path), expectedRevision: record.revision)
    let result = await store.applyOrganizationChanges(changes, now: Date())
    let url = root.appendingPathComponent(project.path.value)
    let occupied = Data("My new file".utf8)
    try occupied.write(to: url)
    let undo = await store.applyOrganizationChanges(result.undo, now: Date())
    #expect(undo.errorMessage != nil && undo.undo.isEmpty)
    #expect(try Data(contentsOf: url) == occupied)
    #expect(try await store.snapshot().tasks[task.path]?.value.project == nil)
}
