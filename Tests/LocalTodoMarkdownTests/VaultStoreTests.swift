import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func storeCreatesAndUpdatesWithRevisionChecks() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Test.md")
    let created = try await store.create(.task(task))
    var patch = TaskPatch()
    patch.title = .set("Updated task")
    let updatedTask = try patch.applying(to: task, now: Date(timeIntervalSince1970: 1_774_608_060))

    let updated = try await store.update(.task(updatedTask), expectedRevision: created.revision)

    #expect(updated.value == .task(updatedTask))
    #expect(updated.revision != created.revision)
    do {
        _ = try await store.update(.task(updatedTask), expectedRevision: created.revision)
        Issue.record("Expected revision conflict")
    } catch let error as VaultStoreError {
        #expect(error == .conflict(task.path))
    }
}

@Test func storeCreatesMissingParentDirectories() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Planning/Test.md")

    _ = try await store.create(.task(task))

    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(task.path.value).path))
}

@Test func failedCreateRemovesNewParentDirectories() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let base = FoundationVaultFileSystem()
    let store = VaultStore(root: root, fileSystem: FailingWriteFileSystem(base: base, failureWrite: 1))
    let task = try testTask(path: "Drafts/Nested/Test.md")

    do {
        _ = try await store.create(.task(task))
        Issue.record("Expected create failure")
    } catch {
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Drafts").path))
    }
}

@Test func storeErrorsDescribeActionableConflicts() throws {
    let path = try VaultPath("Tasks/Test.md")

    #expect(
        VaultStoreError.conflict(path).localizedDescription
            == "The file changed outside Local Todo: Tasks/Test.md. Reload it before saving."
    )
}

@Test func movingProjectUpdatesTaskReferences() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let projectPath = try VaultPath("Projects/Test.md")
    let destination = try VaultPath("Projects/Renamed.md")
    _ = try await store.create(.project(testProject(path: projectPath.value)))
    _ = try await store.create(.task(testTask(path: "Tasks/Test.md", project: projectPath)))

    let snapshot = try await store.move(
        from: projectPath,
        to: destination,
        now: Date(timeIntervalSince1970: 1_774_608_060)
    )

    #expect(snapshot.projects[projectPath] == nil)
    #expect(snapshot.projects[destination]?.value.path == destination)
    #expect(try snapshot.tasks[VaultPath("Tasks/Test.md")]?.value.project == destination)
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(projectPath.value).path))
}

@Test func failedMoveRollsBackEveryFile() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let base = FoundationVaultFileSystem()
    let setupStore = VaultStore(root: root, fileSystem: base)
    let projectPath = try VaultPath("Projects/Test.md")
    let destination = try VaultPath("Projects/Renamed.md")
    _ = try await setupStore.create(.project(testProject(path: projectPath.value)))
    _ = try await setupStore.create(.task(testTask(path: "Tasks/Test.md", project: projectPath)))
    let failing = FailingWriteFileSystem(base: base, failureWrite: 2)
    let store = VaultStore(root: root, fileSystem: failing)

    do {
        _ = try await store.move(
            from: projectPath,
            to: destination,
            now: Date(timeIntervalSince1970: 1_774_608_060)
        )
        Issue.record("Expected move failure")
    } catch {
        let snapshot = try await setupStore.snapshot()
        #expect(snapshot.projects[projectPath] != nil)
        #expect(snapshot.projects[destination] == nil)
        #expect(try snapshot.tasks[VaultPath("Tasks/Test.md")]?.value.project == projectPath)
    }
}

private final class FailingWriteFileSystem: VaultFileSystem, @unchecked Sendable {
    private let base: FoundationVaultFileSystem
    private let failureWrite: Int
    private let lock = NSLock()
    private var writeCount = 0

    init(base: FoundationVaultFileSystem, failureWrite: Int) {
        self.base = base
        self.failureWrite = failureWrite
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try base.contentsOfDirectory(at: url)
    }

    func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
    }

    func exists(at url: URL) -> Bool {
        base.exists(at: url)
    }

    func markdownFiles(in root: URL) throws -> [URL] {
        try base.markdownFiles(in: root)
    }

    func move(from source: URL, to destination: URL) throws {
        try base.move(from: source, to: destination)
    }

    func read(at url: URL) throws -> Data {
        try base.read(at: url)
    }

    func remove(at url: URL) throws {
        try base.remove(at: url)
    }

    func removeEmptyDirectory(at url: URL) throws {
        try base.removeEmptyDirectory(at: url)
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        lock.lock()
        writeCount += 1
        let shouldFail = writeCount == failureWrite
        lock.unlock()
        if shouldFail {
            throw TestFileSystemError.injectedFailure
        }
        try base.writeAtomically(data, to: url)
    }

    func writeExclusively(_ data: Data, to url: URL) throws {
        try base.writeExclusively(data, to: url)
    }
}

private enum TestFileSystemError: Error {
    case injectedFailure
}
