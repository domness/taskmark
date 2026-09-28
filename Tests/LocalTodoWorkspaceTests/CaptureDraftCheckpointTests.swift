import Foundation
import LocalTodoDomain
import LocalTodoWorkspace
import Testing

@Test func captureCheckpointsStayVaultAndRouteBound() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CaptureDraftCheckpointStore(fileURL: root.appendingPathComponent("captures.json"))
    let inbox = CaptureDraftCheckpoint(
        vaultIdentifier: "vault-a", routeKey: "inbox", generation: 1, title: "Inbox draft",
        notes: "", status: nil, priority: nil, scheduled: nil, project: nil, area: nil, tags: []
    )
    let today = CaptureDraftCheckpoint(
        vaultIdentifier: "vault-a", routeKey: "today", generation: 2, title: "Today draft",
        notes: "", status: nil, priority: nil, scheduled: nil, project: nil, area: nil, tags: []
    )
    try await store.save(inbox)
    try await store.save(today)
    try await store.remove(vaultIdentifier: "vault-a", routeKey: "inbox", through: 1)

    #expect(try await store.checkpoints() == [today])
}

@Test func collectionCheckpointsPreserveNewerGenerations() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CollectionDraftCheckpointStore(fileURL: root.appendingPathComponent("collections.json"))
    let path = try VaultPath("projects/launch.md")
    let first = CollectionDraftCheckpoint(
        vaultIdentifier: "vault-a", path: path, baseRevision: "one", generation: 1,
        title: "Launch", body: "First", projectStatus: .active, areaStatus: nil, area: nil, tags: []
    )
    let second = CollectionDraftCheckpoint(
        vaultIdentifier: "vault-a", path: path, baseRevision: "one", generation: 2,
        title: "Launch", body: "Second", projectStatus: .active, areaStatus: nil, area: nil, tags: []
    )
    try await store.save(first)
    try await store.save(second)
    try await store.remove(vaultIdentifier: "vault-a", path: path, through: 1)

    #expect(try await store.checkpoints() == [second])
}

@Test func filterCheckpointsKeepRawInvalidInputAndStayEditorBound() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = FilterDraftCheckpointStore(fileURL: root.appendingPathComponent("filters.json"))
    let checkpoint = FilterDraftCheckpoint(
        vaultIdentifier: "vault-a", editorKey: "existing:Due soon", originalName: "Due soon",
        baseRevision: "revision", generation: 2, name: "Due soon", view: .upcoming, text: "",
        includeCompleted: false, sort: .priority, statuses: [.next], priorities: [.p1],
        includesNoPriority: false, projectPath: "", areaPath: "", tagsText: "important",
        scheduledFrom: "not-a-date-yet", scheduledThrough: "", deadlineFrom: "", deadlineThrough: ""
    )
    try await store.save(checkpoint)
    try await store.remove(vaultIdentifier: "vault-a", editorKey: "existing:Due soon", through: 1)

    #expect(try await store.checkpoints() == [checkpoint])
}
