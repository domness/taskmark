import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func duplicateSkipsOccupiedPathsAndReopensCompletedTask() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let task = try TodoTask(
        path: VaultPath("Tasks/source.md"), title: "Source", status: .done,
        recurrence: .afterCompletion(RecurrenceInterval(value: 2, unit: .day)),
        body: "- [x] Keep this\n", createdAt: now, updatedAt: now, completedAt: now
    )
    let record = try await store.create(.task(task))
    let occupied = root.appendingPathComponent("Tasks/source-copy.md")
    try Data("User-owned malformed content".utf8).write(to: occupied)
    let copy = try await store.duplicateTask(
        at: task.path,
        expectedRevision: record.revision,
        now: now.addingTimeInterval(60)
    )
    guard case let .task(duplicated) = copy.value else { Issue.record("Expected task"); return }
    #expect(duplicated.path.value == "Tasks/source-copy-2.md")
    #expect(duplicated.status == .inbox)
    #expect(duplicated.completedAt == nil)
    #expect(duplicated.createdAt == now.addingTimeInterval(60))
    #expect(duplicated.recurrence == task.recurrence)
    #expect(duplicated.body == task.body)
    #expect(try String(contentsOf: occupied, encoding: .utf8) == "User-owned malformed content")
}

@Test func taskContentRestorationRejectsOccupiedPathsAndSymlinks() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let task = try testTask(path: "Tasks/source.md")
    let record = try await store.create(.task(task))
    let data = try await store.taskContent(at: task.path, expectedRevision: record.revision)
    await #expect(throws: VaultStoreError.self) { try await store.restoreTaskContent(data, at: task.path) }
    let link = root.appendingPathComponent("Linked")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("Tasks"))
    await #expect(throws: VaultStoreError.self) {
        try await store.restoreTaskContent(data, at: VaultPath("Linked/copy.md"))
    }
    #expect(try Data(contentsOf: root.appendingPathComponent(task.path.value)) == data)
}

@Test func stylesheetRejectsSymlinkEntryPoint() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let original = root.appendingPathComponent("ConfigurationCopy")
    try FileManager.default.moveItem(at: root.appendingPathComponent(".config"), to: original)
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(".config"), withDestinationURL: original)
    await #expect(throws: VaultStoreError.self) { try await VaultStore(root: root).stylesheet() }
}
