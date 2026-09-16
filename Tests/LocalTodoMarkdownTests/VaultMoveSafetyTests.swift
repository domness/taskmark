import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func taskMovePreservesExactFileBytes() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Original.md")
    _ = try await store.create(.task(task))
    let sourceURL = root.appendingPathComponent(task.path.value)
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
        .replacingOccurrences(of: "type: task", with: "# Keep this comment\ntype: task\ncustom: 'keep quoting'")
    let bytes = Data(source.utf8)
    try bytes.write(to: sourceURL)
    let destination = try VaultPath("Tasks/Moved.md")

    _ = try await store.move(from: task.path, to: destination, now: Date())

    #expect(try Data(contentsOf: root.appendingPathComponent(destination.value)) == bytes)
    #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
}

@Test func taskMoveRejectsCoordinatorIdentityRemap() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let setup = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Original.md")
    _ = try await setup.create(.task(task))
    let destination = try VaultPath("Tasks/Moved.md")
    let fileSystem = FailingWriteFileSystem(
        base: FoundationVaultFileSystem(), failureWrite: .max,
        coordinatedURL: root.appendingPathComponent("Tasks/Unexpected.md")
    )
    let store = VaultStore(root: root, fileSystem: fileSystem)

    await #expect(throws: VaultStoreError.self) {
        try await store.move(from: task.path, to: destination, now: Date())
    }
    #expect(try await setup.snapshot().tasks[task.path] != nil)
    #expect(try await setup.snapshot().tasks[destination] == nil)
}

@Test func taskMoveRejectsOccupiedDestination() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Original.md")
    let destination = try testTask(path: "Tasks/Occupied.md")
    _ = try await store.create(.task(task))
    _ = try await store.create(.task(destination))

    await #expect(throws: VaultStoreError.destinationExists(destination.path)) {
        try await store.move(from: task.path, to: destination.path, now: Date())
    }
    #expect(try await store.snapshot().tasks.count == 2)
}

@Test func filesystemRenameNeverReplacesDestination() throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let source = root.appendingPathComponent("Tasks/Source.md")
    let destination = root.appendingPathComponent("Tasks/Destination.md")
    try Data("source".utf8).write(to: source)
    try Data("external content".utf8).write(to: destination)

    #expect(throws: (any Error).self) {
        try FoundationVaultFileSystem().move(from: source, to: destination)
    }
    #expect(try Data(contentsOf: source) == Data("source".utf8))
    #expect(try Data(contentsOf: destination) == Data("external content".utf8))
}

@Test(arguments: ["missing", "schema: [", "schema: 999\n"])
func taskMoveRejectsInvalidManifestBeforeMutation(manifest: String) async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Original.md")
    _ = try await store.create(.task(task))
    let manifestURL = root.appendingPathComponent(LocalTodoSchema.manifestPath)
    if manifest == "missing" {
        try FileManager.default.removeItem(at: manifestURL)
    } else {
        try Data(manifest.utf8).write(to: manifestURL)
    }
    let sourceURL = root.appendingPathComponent(task.path.value)
    let original = try Data(contentsOf: sourceURL)
    let destination = try VaultPath("Tasks/Moved.md")

    await #expect(throws: VaultStoreError.self) {
        try await store.validateMove(from: task.path, to: destination)
    }
    await #expect(throws: VaultStoreError.self) {
        try await store.move(from: task.path, to: destination, now: Date())
    }
    #expect(try Data(contentsOf: sourceURL) == original)
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(destination.value).path))
}
