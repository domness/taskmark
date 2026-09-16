import Foundation
import LocalTodoDomain
@testable import LocalTodoMarkdown
import Testing

@Test(arguments: [".localtodo/Task.md", ".LocalTodo/Task.md", "Bad\0Name.md", "../Task.md", "Tasks\\Task.md"])
func pathSafetyRevalidatesDecodedPaths(value: String) async throws {
    let data = try JSONEncoder().encode(["value": value])
    let path = try JSONDecoder().decode(VaultPath.self, from: data)
    let root = try makeTestVault()
    defer { removeTestVault(root) }

    await #expect(throws: DomainValidationError.invalidVaultPath) {
        try await VaultStore(root: root).validateEntityPath(path)
    }
}

@Test(arguments: ["outside", "inside", "dangling"], ["Alias/Task.md", "Alias/New/Task.md", "Alias.md"])
func pathSafetyRejectsSymbolicLinkComponents(target: String, path: String) async throws {
    let root = try makeTestVault()
    let outside = try makeTestVault()
    defer {
        removeTestVault(root)
        removeTestVault(outside)
    }
    let destination = switch target {
    case "outside": outside
    case "inside": root.appendingPathComponent("Tasks")
    default: root.appendingPathComponent("Missing")
    }
    let component = path.hasPrefix("Alias/") ? "Alias" : "Alias.md"
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent(component),
        withDestinationURL: destination
    )
    let store = VaultStore(root: root)

    await #expect(throws: VaultStoreError.invalidVault("Symbolic links are not allowed in entity path: \(path)")) {
        try await store.validateEntityPath(VaultPath(path))
    }
}

@Test func pathSafetyRejectsExistingFileLinksForUpdateDeleteAndMoveSource() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let original = root.appendingPathComponent("Tasks/Original.md")
    let data = Data("Keep original content".utf8)
    try data.write(to: original)
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("Tasks/Alias.md"),
        withDestinationURL: original
    )

    await #expect(throws: VaultStoreError.invalidVault(
        "Symbolic links are not allowed in entity path: Tasks/Alias.md"
    )) {
        try await VaultStore(root: root).validateEntityPath(VaultPath("Tasks/Alias.md"))
    }
    #expect(try Data(contentsOf: original) == data)
}

@Test func pathSafetyAllowsRegularAndMissingCreateAndMoveDestinationsThroughLinkedRoot() async throws {
    let container = try makeTestVault()
    defer { removeTestVault(container) }
    let root = container.appendingPathComponent("Actual")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let alias = container.appendingPathComponent("RootAlias")
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
    try Data("Existing".utf8).write(to: root.appendingPathComponent("Task.md"))
    let store = VaultStore(root: alias)

    try await store.validateEntityPath(VaultPath("Task.md"))
    try await store.validateEntityPath(VaultPath("New/Nested/Task.md"))
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("New").path))
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("Child"),
        withDestinationURL: root
    )
    await #expect(throws: VaultStoreError.invalidVault(
        "Symbolic links are not allowed in entity path: Child/Task.md"
    )) {
        try await store.validateEntityPath(VaultPath("Child/Task.md"))
    }
}

@Test func pathSafetyPropagatesMetadataErrors() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    try Data("Not a directory".utf8).write(to: root.appendingPathComponent("File"))

    await #expect {
        try await VaultStore(root: root).validateEntityPath(VaultPath("File/Task.md"))
    } throws: { error in
        guard case VaultStoreError.inputOutput = error else { return false }
        return true
    }
}

@Test(arguments: ["create", "update", "delete", "move-source", "move-destination"])
func mutationsRejectSymlinkedParent(operation: String) async throws {
    let root = try makeTestVault()
    let outside = try makeTestVault()
    defer {
        removeTestVault(root)
        removeTestVault(outside)
    }
    let externalStore = VaultStore(root: outside)
    let external = try testTask(path: "Tasks/External.md")
    let record = try await externalStore.create(.task(external))
    let original = try Data(contentsOf: outside.appendingPathComponent(external.path.value))
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("Alias"),
        withDestinationURL: outside.appendingPathComponent("Tasks")
    )
    let store = VaultStore(root: root)
    let alias = try testTask(path: "Alias/External.md")
    let local = try testTask(path: "Tasks/Local.md")
    _ = try await store.create(.task(local))

    await #expect(throws: VaultStoreError.self) {
        switch operation {
        case "create":
            _ = try await store.create(.task(testTask(path: "Alias/New.md")))
        case "update":
            _ = try await store.update(.task(alias), expectedRevision: record.revision)
        case "delete":
            _ = try await store.delete(at: alias.path, expectedRevision: record.revision)
        case "move-source":
            _ = try await store.move(from: alias.path, to: VaultPath("Tasks/Moved.md"), now: Date())
        default:
            _ = try await store.move(from: local.path, to: VaultPath("Alias/New.md"), now: Date())
        }
    }
    #expect(try Data(contentsOf: outside.appendingPathComponent(external.path.value)) == original)
    #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("Tasks/New.md").path))
    #expect(try await store.snapshot().tasks[local.path] != nil)
}
