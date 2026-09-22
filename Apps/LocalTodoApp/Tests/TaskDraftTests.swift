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
    draft.tags = ["work", "launch"]
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

@MainActor
@Test func taskDraftAdoptsAnAssignmentWhilePreservingAnOverlappingEdit() throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    var patch = TaskPatch()
    let project = try VaultPath("Projects/Launch.md")
    patch.project = .set(project)
    let savedTask = try patch.applying(to: original.value, now: Date())
    let saved = VaultRecord(value: savedTask, revision: FileRevision(data: Data("second".utf8)))
    let draft = TaskDraft(record: original, vaultSession: UUID())
    let generation = draft.generation
    draft.notes = "Typed while assigning"

    draft.acceptOrganizationSave(saved, generation: generation, field: .project)

    #expect(draft.project == project.value)
    #expect(draft.notes == "Typed while assigning")
    #expect(draft.isDirty)
    let merged = try draft.patch().applying(to: draft.sourceTask, now: Date())
    #expect(merged.project == project)
    #expect(merged.body == "Typed while assigning")
}

@MainActor
@Test func taskDraftRebasesLocalEditsOntoExternalChanges() throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    let external = try taskRecord(
        path: "Tasks/One.md",
        title: "External title",
        revision: "second",
        notes: "External notes"
    )
    let draft = TaskDraft(record: original, vaultSession: UUID())
    draft.notes = "Local notes"

    draft.rebase(to: external)

    #expect(draft.title == "External title")
    #expect(draft.notes == "Local notes")
    #expect(draft.revision == external.revision)
    let merged = try draft.patch().applying(to: draft.sourceTask, now: Date())
    #expect(merged.title == "External title")
    #expect(merged.body == "Local notes")
}

@MainActor
@Test(arguments: [false, true])
func taskDraftReconcilesTagDropWithTyping(editedTags: Bool) throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    var patch = TaskPatch()
    patch.tags = .set(["dropped"])
    let saved = try VaultRecord(
        value: patch.applying(to: original.value, now: Date()),
        revision: FileRevision(data: Data("second".utf8))
    )
    let draft = TaskDraft(record: original, vaultSession: UUID())
    let generation = draft.generation
    draft.notes = "Typed while dropping"
    if editedTags {
        draft.tags = ["typed"]
    }
    draft.acceptOrganizationSave(saved, generation: generation, field: .tags)
    let merged = try draft.patch().applying(to: draft.sourceTask, now: Date())
    #expect(merged.tags == (editedTags ? ["typed"] : ["dropped"]))
    #expect(merged.body == "Typed while dropping")
    #expect(draft.isDirty)
}

@MainActor
@Test func taskDraftSurfacesOverlappingExternalChanges() throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    let external = try taskRecord(path: "Tasks/One.md", title: "External", revision: "second")
    let draft = TaskDraft(record: original, vaultSession: UUID())
    draft.title = "Local"

    draft.rebase(to: external)

    #expect(draft.hasConflicts)
    #expect(draft.conflictedFields == [.title])
    #expect(draft.title == "Local")
    #expect(draft.sourceTask.title == "External")
}

@MainActor
@Test func taskDraftClearsConflictWhenExternalValueConverges() throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    let conflicting = try taskRecord(path: "Tasks/One.md", title: "External", revision: "second")
    let converged = try taskRecord(path: "Tasks/One.md", title: "Local", revision: "third")
    let draft = TaskDraft(record: original, vaultSession: UUID())
    draft.title = "Local"

    draft.rebase(to: conflicting)
    #expect(draft.hasConflicts)

    draft.rebase(to: converged)

    #expect(!draft.hasConflicts)
    #expect(!draft.isDirty)
    #expect(draft.title == "Local")
}

@MainActor
@Test func taskDraftTransfersEditsMadeWhileSavingToACopy() throws {
    let original = try taskRecord(path: "Tasks/One.md", title: "Original", revision: "first")
    let savedCopy = try taskRecord(path: "Tasks/Copy.md", title: "First edit", revision: "second")
    let draft = TaskDraft(record: original, vaultSession: UUID())
    draft.title = "First edit"
    _ = draft.beginSaving()
    draft.notes = "Typed while saving"
    let copy = TaskDraft(record: savedCopy, vaultSession: draft.vaultSession)

    draft.transferCurrentValues(to: copy)

    #expect(copy.title == "First edit")
    #expect(copy.notes == "Typed while saving")
    #expect(copy.isDirty)
}

private func taskRecord(
    path: String,
    title: String,
    revision: String,
    notes: String = ""
) throws -> VaultRecord<TodoTask> {
    let timestamp = Date(timeIntervalSince1970: 1_774_608_000)
    let task = try TodoTask(
        path: VaultPath(path),
        title: title,
        status: .next,
        body: notes,
        createdAt: timestamp,
        updatedAt: timestamp
    )
    return VaultRecord(value: task, revision: FileRevision(data: Data(revision.utf8)))
}
