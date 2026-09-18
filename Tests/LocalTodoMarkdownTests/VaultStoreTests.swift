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

@Test func storeUpdatePreservesUnknownFrontmatterAndBodyBytes() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let path = try VaultPath("Tasks/Test.md")
    let timestamp = Date(timeIntervalSince1970: 1_774_608_000)
    let task = try TodoTask(
        path: path,
        title: "Original",
        status: .next,
        body: "Line one\r\nLine two\r\n",
        createdAt: timestamp,
        updatedAt: timestamp
    )
    let store = VaultStore(root: root)
    _ = try await store.create(.task(task))
    let url = root.appendingPathComponent(path.value)
    let createdSource = try String(contentsOf: url, encoding: .utf8)
    let source = createdSource.replacingOccurrences(of: "type: task\n", with: "type: task\ncustom: keep\n")
    try Data(source.utf8).write(to: url)
    let current = try #require(try await store.snapshot().tasks[path])
    var patch = TaskPatch()
    patch.title = .set("Updated")
    let updated = try patch.applying(to: current.value, now: Date(timeIntervalSince1970: 1_774_608_060))

    _ = try await store.update(.task(updated), expectedRevision: current.revision)

    let saved = try String(contentsOf: url, encoding: .utf8)
    #expect(saved.contains("custom: keep"))
    #expect(saved.hasSuffix("Line one\r\nLine two\r\n"))
}

@Test func storeCreatesMissingParentDirectories() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Planning/Test.md")

    _ = try await store.create(.task(task))

    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(task.path.value).path))
}

@Test func storeCreateDoesNotReplaceAnExistingEntity() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let original = try testTask(path: "Tasks/Test.md")
    _ = try await store.create(.task(original))
    var patch = TaskPatch()
    patch.title = .set("Replacement")
    let replacement = try patch.applying(to: original, now: Date())

    await #expect(throws: VaultStoreError.destinationExists(original.path)) {
        try await store.create(.task(replacement))
    }

    #expect(try await store.snapshot().tasks[original.path]?.value.title == original.title)
}

@Test func storeDeletesOnlyTheExpectedRevision() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Test.md")
    let created = try await store.create(.task(task))

    let deleted = try await store.delete(at: task.path, expectedRevision: created.revision)

    #expect(deleted == .task(task))
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(task.path.value).path))
    await #expect(throws: VaultStoreError.notFound(task.path)) {
        try await store.delete(at: task.path, expectedRevision: created.revision)
    }
}

@Test func storeRejectsDeleteWithAStaleRevision() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/Test.md")
    let created = try await store.create(.task(task))
    var patch = TaskPatch()
    patch.title = .set("Updated")
    let updated = try patch.applying(to: task, now: Date())
    _ = try await store.update(.task(updated), expectedRevision: created.revision)

    await #expect(throws: VaultStoreError.conflict(task.path)) {
        try await store.delete(at: task.path, expectedRevision: created.revision)
    }
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(task.path.value).path))
}

@Test func storeRejectsAFileCoordinatorIdentityRemap() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let base = FoundationVaultFileSystem()
    let setupStore = VaultStore(root: root, fileSystem: base)
    let task = try testTask(path: "Tasks/Test.md")
    let created = try await setupStore.create(.task(task))
    let remappedURL = root.appendingPathComponent("Tasks/Moved.md")
    let fileSystem = FailingWriteFileSystem(
        base: base,
        failureWrite: .max,
        coordinatedURL: remappedURL
    )
    let store = VaultStore(root: root, fileSystem: fileSystem)
    var patch = TaskPatch()
    patch.title = .set("Should not save")
    let updated = try patch.applying(to: task, now: Date())

    await #expect(throws: VaultStoreError.conflict(task.path)) {
        try await store.update(.task(updated), expectedRevision: created.revision)
    }

    #expect(try await setupStore.snapshot().tasks[task.path]?.value.title == task.title)
    #expect(!base.exists(at: remappedURL))
}

@Test func storeRefusesToDeleteReferencedCollections() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let created = try await store.create(.project(project))
    _ = try await store.create(.task(testTask(path: "Tasks/Test.md", project: project.path)))

    await #expect(throws: VaultStoreError.invalidVault(
        "Cannot delete Projects/Test.md while tasks, projects, or saved filters reference it. "
            + "Remove those references first."
    )) {
        try await store.delete(at: project.path, expectedRevision: created.revision)
    }
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
            == "The file changed outside Taskmark: Tasks/Test.md. Reload it before saving."
    )
}

@Test func movingReferencedProjectIsRejectedWithoutChangingFiles() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let projectPath = try VaultPath("Projects/Test.md")
    let destination = try VaultPath("Projects/Renamed.md")
    _ = try await store.create(.project(testProject(path: projectPath.value)))
    _ = try await store.create(.task(testTask(path: "Tasks/Test.md", project: projectPath)))

    let original = try Data(contentsOf: root.appendingPathComponent(projectPath.value))
    let taskURL = root.appendingPathComponent("Tasks/Test.md")
    let originalTask = try Data(contentsOf: taskURL)
    await #expect(throws: VaultStoreError.self) {
        try await store.move(from: projectPath, to: destination, now: Date())
    }
    let snapshot = try await store.snapshot()

    #expect(snapshot.projects[projectPath] != nil)
    #expect(snapshot.projects[destination] == nil)
    #expect(try Data(contentsOf: root.appendingPathComponent(projectPath.value)) == original)
    #expect(try Data(contentsOf: taskURL) == originalTask)
}

@Test func failedTaskRenameLeavesBothPathsUnchanged() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let base = FoundationVaultFileSystem()
    let setupStore = VaultStore(root: root, fileSystem: base)
    let source = try VaultPath("Tasks/Test.md")
    let destination = try VaultPath("Tasks/Renamed.md")
    _ = try await setupStore.create(.task(testTask(path: source.value)))
    let original = try Data(contentsOf: root.appendingPathComponent(source.value))
    let failing = FailingWriteFileSystem(base: base, failureWrite: 1)
    let store = VaultStore(root: root, fileSystem: failing)

    do {
        _ = try await store.move(
            from: source,
            to: destination,
            now: Date(timeIntervalSince1970: 1_774_608_060)
        )
        Issue.record("Expected move failure")
    } catch {
        let snapshot = try await setupStore.snapshot()
        #expect(snapshot.tasks[source] != nil)
        #expect(snapshot.tasks[destination] == nil)
        #expect(try Data(contentsOf: root.appendingPathComponent(source.value)) == original)
    }
}
