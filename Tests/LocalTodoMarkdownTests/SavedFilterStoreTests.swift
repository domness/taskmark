import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func savedFiltersRoundTripEveryQueryFieldAndPreserveUnknownContent() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let url = root.appendingPathComponent(VaultStore.savedFiltersPath)
    let source = "---\nschema: 1\nplugin: keep\nfilters:\n  - name: Focus\n"
        + "    plugin_filter: [keep, me]\n---\nNotes 🦊\r\n"
    try Data(source.utf8).write(to: url)
    let store = VaultStore(root: root)
    let original = try await store.savedFilters()
    var filters = TaskFilters()
    filters.project = try VaultPath("Projects/Exact.md")
    filters.area = try VaultPath("Areas/Work.md")
    filters.statuses = [.next, .waiting]
    filters.priorities = [.p1, .p3]
    filters.includesNoPriority = true
    filters.tags = ["work", "desk"]
    filters.scheduled = try DateRange(start: CalendarDate("2026-09-01"), end: CalendarDate("2026-09-30"))
    filters.deadline = try DateRange(start: CalendarDate("2026-09-02"), end: CalendarDate("2026-10-01"))
    let filter = try SavedTaskFilter(name: "Focus", query: TaskQuery(
        scope: .upcoming, text: "review", filters: filters, includeCompleted: true, sort: .deadline
    ))
    let saved = try await store.saveFilters([filter], expectedRevision: original.revision)
    #expect(try await VaultStore(root: root).savedFilters() == saved)
    #expect(saved.filters == [filter])
    let rendered = try String(contentsOf: url, encoding: .utf8)
    #expect(rendered.contains("plugin_filter:"))
    #expect(rendered.contains("- keep"))
    let document = try MarkdownDocument.parse(rendered)
    #expect(document.string(forKey: "plugin") == "keep")
    #expect(document.body == "Notes 🦊\r\n")
    #expect(try await store.snapshot().tasks.isEmpty)
}

@Test func savedFilterWritesCheckRevisionIncludingCreationAndDeletion() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    #expect(try await store.savedFilters() == SavedFilterRecord())
    let filter = try SavedTaskFilter(name: "Today", query: TaskQuery(scope: .today))
    let first = try await store.saveFilters([filter], expectedRevision: nil)
    await #expect(throws: SavedFilterError.conflict) {
        try await store.saveFilters([], expectedRevision: nil)
    }
    let url = root.appendingPathComponent(VaultStore.savedFiltersPath)
    let bytes = try Data(contentsOf: url)
    try Data((String(contentsOf: url, encoding: .utf8) + "External notes").utf8).write(to: url)
    await #expect(throws: SavedFilterError.conflict) {
        try await store.saveFilters([], expectedRevision: first.revision)
    }
    try FileManager.default.removeItem(at: url)
    await #expect(throws: SavedFilterError.conflict) {
        try await store.saveFilters([], expectedRevision: first.revision)
    }
    try bytes.write(to: url)
    _ = try await store.saveFilters([], expectedRevision: first.revision)
    #expect(try await VaultStore(root: root).savedFilters().filters.isEmpty)
}

@Test func failedSavedFilterReplacementLeavesOriginalBytes() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let first = try await store.saveFilters([SavedTaskFilter(name: "Keep", query: TaskQuery())], expectedRevision: nil)
    let url = root.appendingPathComponent(VaultStore.savedFiltersPath)
    let bytes = try Data(contentsOf: url)
    let failing = VaultStore(
        root: root,
        fileSystem: FailingWriteFileSystem(base: FoundationVaultFileSystem(), failureWrite: 1)
    )
    await #expect(throws: VaultStoreError.self) { try await failing.saveFilters([], expectedRevision: first.revision) }
    #expect(try Data(contentsOf: url) == bytes)
}

@Test(arguments: [
    "schema: 2\nfilters: []", "schema: 1\nfilters: {}", "schema: 1\nfilters: [bad]",
    "schema: 1\nfilters: [{name: Same}, {name: Same}]",
    "schema: 1\nfilters: [{name: Bad, scheduled_from: 2026-09-20, scheduled_through: 2026-09-01}]",
    "schema: 1\nfilters: [{name: Bad, priorities: [p5]}]",
    "schema: 1\nfilters: [{name: Bad, project: ../escape.md}]",
])
func malformedSavedFiltersAreNotOverwritten(yaml: String) async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let url = root.appendingPathComponent(VaultStore.savedFiltersPath)
    let bytes = Data("---\n\(yaml)\n---\nKeep notes".utf8)
    try bytes.write(to: url)
    let store = VaultStore(root: root)
    await #expect(throws: SavedFilterError.self) { try await store.savedFilters() }
    await #expect(throws: SavedFilterError.self) {
        try await store.saveFilters([], expectedRevision: FileRevision(data: bytes))
    }
    #expect(try Data(contentsOf: url) == bytes)
    #expect(try await store.snapshot().diagnostics.contains { $0.field == "filters" })
}

@Test func savedFiltersSurfaceMissingProjectReferences() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    var filters = TaskFilters()
    filters.project = try VaultPath("Projects/Missing.md")
    let saved = try SavedTaskFilter(name: "Missing project", query: TaskQuery(filters: filters))
    let store = VaultStore(root: root)
    _ = try await store.saveFilters([saved], expectedRevision: nil)
    #expect(try await store.snapshot().diagnostics.contains {
        $0.kind == .referenceMissing && $0.reference == filters.project
    })
}

@Test func clearingSavedFilterCriteriaPersistsAfterReload() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    var fields = TaskFilters()
    fields.project = try VaultPath("Projects/Old.md")
    fields.area = try VaultPath("Areas/Old.md")
    fields.scheduled = try DateRange(start: CalendarDate("2026-09-01"), end: CalendarDate("2026-09-30"))
    fields.deadline = fields.scheduled
    let store = VaultStore(root: root)
    let original = try SavedTaskFilter(name: "Clear me", query: TaskQuery(text: "old text", filters: fields))
    let record = try await store.saveFilters([original], expectedRevision: nil)
    let cleared = try SavedTaskFilter(name: original.name, query: TaskQuery())
    _ = try await store.saveFilters([cleared], expectedRevision: record.revision)
    #expect(try await VaultStore(root: root).savedFilters().filters == [cleared])
}
