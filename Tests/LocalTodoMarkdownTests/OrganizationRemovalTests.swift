import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test(arguments: [TaskStatus.next, .done, .canceled])
func organizationRemovalPreservesTaskContentAndCompletion(status: TaskStatus) async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let project = try testProject(path: "Projects/Test.md")
    let record = try await store.create(.project(project))
    let now = Date(timeIntervalSince1970: 1_774_608_000)
    let task = try TodoTask(
        path: VaultPath("Tasks/Test.md"), title: "Keep me", status: status, project: project.path,
        tags: ["keep"], body: "Notes 🦊\r\n- [x] Done\r\n", createdAt: now, updatedAt: now,
        completedAt: status == .done ? now : nil
    )
    _ = try await store.create(.task(task))
    let url = root.appendingPathComponent(task.path.value)
    let original = try String(contentsOf: url, encoding: .utf8)
    try original.replacingOccurrences(of: "type: task", with: "type: task\ncustom: [one, two]")
        .write(to: url, atomically: true, encoding: .utf8)
    let changes = try await store.planOrganizationRemoval(.project(project.path), expectedRevision: record.revision)
    let result = await store.applyOrganizationChanges(changes, now: now.addingTimeInterval(60))
    #expect(result.errorMessage == nil)
    let snapshot = try await store.snapshot()
    let saved = try #require(snapshot.tasks[task.path]?.value)
    #expect(snapshot.projects.isEmpty)
    #expect(saved.project == nil)
    #expect(saved.status == status && saved.completedAt == task.completedAt)
    #expect(saved.body == task.body && saved.tags == task.tags)
    let document = try MarkdownDocument.parse(String(contentsOf: url, encoding: .utf8))
    #expect(document.strings(forKey: "custom") == ["one", "two"])
    let undone = await store.applyOrganizationChanges(result.undo, now: now.addingTimeInterval(120))
    #expect(undone.errorMessage == nil)
    #expect(try await store.snapshot().tasks[task.path]?.value.project == project.path)
    #expect(await store.applyOrganizationChanges(undone.undo, now: now).errorMessage == nil)
    #expect(try await store.snapshot().projects.isEmpty)
}

@Test func areaRemovalClearsProjectsTasksAndSavedFilters() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let area = try testArea(path: "Areas/Test.md")
    let record = try await store.create(.area(area))
    let project = try testProject(path: "Projects/Test.md", area: area.path)
    _ = try await store.create(.project(project))
    let task = try testTask(path: "Tasks/Test.md", project: project.path, area: area.path)
    _ = try await store.create(.task(task))
    var query = TaskQuery(includeCompleted: true)
    query.filters.area = area.path
    query.filters.project = project.path
    let filter = try SavedTaskFilter(name: "Work", query: query)
    _ = try await store.saveFilters([filter], expectedRevision: nil)
    let changes = try await store.planOrganizationRemoval(.area(area.path), expectedRevision: record.revision)
    let result = await store.applyOrganizationChanges(changes, now: Date())
    #expect(result.errorMessage == nil)
    let snapshot = try await store.snapshot()
    #expect(snapshot.areas.isEmpty)
    #expect(snapshot.projects[project.path]?.value.area == nil)
    #expect(snapshot.tasks[task.path]?.value.area == nil)
    #expect(snapshot.tasks[task.path]?.value.project == project.path)
    let saved = try #require(try await store.savedFilters().filters.first)
    #expect(saved.query.filters.area == nil && saved.query.filters.project == project.path)
    #expect(saved.query.includeCompleted)
    #expect(await store.applyOrganizationChanges(result.undo, now: Date()).errorMessage == nil)
    #expect(try await store.savedFilters().filters == [filter])
    #expect(try await store.snapshot().projects[project.path]?.value.area == area.path)
}

@Test func tagRemovalIsExactAndIncludesAllEntityKindsAndFilters() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let entities: [LocalTodoEntity] = try [
        .task(testTask(path: "Tasks/Test.md")), .project(testProject(path: "Projects/Test.md")),
        .area(testArea(path: "Areas/Test.md")),
    ]
    for entity in entities {
        _ = try await store.create(entity)
        let url = root.appendingPathComponent(entity.path.value)
        var doc = try MarkdownDocument.parse(String(contentsOf: url, encoding: .utf8))
        doc.set(.strings(["remove", "Remove", "keep"]), for: .tags)
        try doc.rendered().write(to: url, atomically: true, encoding: .utf8)
    }
    var query = TaskQuery()
    query.filters.tags = ["remove", "keep"]
    _ = try await store.saveFilters([SavedTaskFilter(name: "Tagged", query: query)], expectedRevision: nil)
    let changes = try await store.planOrganizationRemoval(.tag("remove"))
    let result = await store.applyOrganizationChanges(changes, now: Date())
    #expect(result.errorMessage == nil)
    for entity in entities {
        let doc = try MarkdownDocument.parse(String(
            contentsOf: root.appendingPathComponent(entity.path.value),
            encoding: .utf8
        ))
        #expect(doc.strings(forKey: "tags") == ["Remove", "keep"])
    }
    #expect(try await store.savedFilters().filters.first?.query.filters.tags == ["keep"])
    #expect(await store.applyOrganizationChanges(result.undo, now: Date()).errorMessage == nil)
    #expect(try await store.snapshot().tasks.values.first?.value.tags == ["remove", "Remove", "keep"])
}
