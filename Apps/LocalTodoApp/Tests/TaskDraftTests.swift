import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func taskDraftRetainsOriginalIdentityUntilReset() throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    let external = try taskRecord(path: "Tasks/One.md", title: "External", revision: "second")
    let draft = TaskDraft(record: original, vaultSession: UUID())

    draft.title = "Local edit"

    #expect(draft.isDirty)
    #expect(draft.path == original.value.path)
    #expect(draft.revision == original.revision)
    #expect(draft.sourceTask.title == "Original")

    draft.reset(to: external)

    #expect(!draft.isDirty)
    #expect(draft.title == "External")
    #expect(draft.revision == external.revision)
}

@MainActor
@Test func taskDraftBuildsTypedPatch() throws {
    let record = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    let draft = TaskDraft(record: record, vaultSession: UUID())
    draft.title = "Updated"
    draft.status = .waiting
    draft.scheduled = "2026-08-01"
    draft.tags = "work, launch"
    draft.notes = "Preserved notes"

    let updated = try draft.patch().applying(
        to: draft.sourceTask,
        now: Date(timeIntervalSince1970: 1_775_000_000)
    )

    #expect(updated.path == record.value.path)
    #expect(updated.title == "Updated")
    #expect(updated.status == .waiting)
    #expect(try updated.scheduled == CalendarDate("2026-08-01"))
    #expect(updated.tags == ["work", "launch"])
    #expect(updated.body == "Preserved notes")
}

@MainActor
@Test func taskDraftPreservesTypingThatOccursDuringSave() throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    let saved = try taskRecord(path: "Tasks/One.md", title: "First edit", revision: "second")
    let draft = TaskDraft(record: original, vaultSession: UUID())
    draft.title = "First edit"
    let generation = try #require(draft.beginSaving())

    draft.title = "Later edit"
    draft.acceptSave(saved, generation: generation)

    #expect(draft.isDirty)
    #expect(!draft.isSaving)
    #expect(draft.title == "Later edit")
    #expect(draft.sourceTask.title == "First edit")
    #expect(draft.revision == saved.revision)
}

private func taskRecord(path: String, title: String, revision: String) throws -> VaultRecord<TodoTask> {
    let timestamp = Date(timeIntervalSince1970: 1_774_608_000)
    let task = try TodoTask(
        path: VaultPath(path),
        title: title,
        status: .next,
        createdAt: timestamp,
        updatedAt: timestamp
    )
    return VaultRecord(value: task, revision: FileRevision(data: Data(revision.utf8)))
}
