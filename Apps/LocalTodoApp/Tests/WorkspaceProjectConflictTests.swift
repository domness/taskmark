import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test(arguments: [false, true])
func projectEditingRebasesOrSurfacesConflicts(overlap: Bool) async throws {
    try await withWorkspace { model, root in
        let draft = try await makeProjectDraft(model)
        draft.title = "Local title"
        let store = VaultStore(root: root)
        let original = try #require(try await store.snapshot().projects[draft.path])
        var patch = ProjectPatch()
        if overlap {
            patch.title = .set("External title")
        } else {
            patch.body = .set("External notes")
        }
        _ = try await store.update(
            .project(patch.applying(to: original.value, now: Date())),
            expectedRevision: original.revision
        )
        await model.updateProject(draft)
        let saved = try #require(try await VaultStore(root: root).snapshot().projects[draft.path]?.value)
        if overlap {
            #expect(draft.conflicts == [.title])
            #expect(saved.title == "External title")
            #expect(await !(model.flushTaskChanges()))
            draft.keepLocalChanges()
            #expect(await model.flushTaskChanges())
            #expect(try await VaultStore(root: root).snapshot().projects[draft.path]?.value.title == "Local title")
        } else {
            #expect(draft.conflicts.isEmpty)
            #expect(saved.title == "Local title")
            #expect(saved.body == "External notes")
        }
    }
}

@MainActor
@Test func unavailableProjectDoesNotOverwriteMalformedContent() async throws {
    try await withWorkspace { model, root in
        let draft = try await makeProjectDraft(model)
        draft.notes = "Unsaved notes"
        let url = root.appendingPathComponent(draft.path.value)
        let original = try Data(contentsOf: url)
        let malformed = Data("---\ntype: project\n[bad yaml\n---\nKeep me".utf8)
        try malformed.write(to: url)
        await model.updateProject(draft)
        #expect(draft.isDirty)
        #expect(draft.unavailableMessage != nil)
        #expect(await !(model.flushTaskChanges()))
        #expect(try Data(contentsOf: url) == malformed)
        try original.write(to: url)
        await model.refresh()
        #expect(await model.flushTaskChanges())
        #expect(try await VaultStore(root: root).snapshot().projects[draft.path]?.value.body == "Unsaved notes")
    }
}

@MainActor
@Test func projectWriteFailureRetainsDraftAndCanRetry() async throws {
    try await withWorkspace { model, root in
        let draft = try await makeProjectDraft(model)
        let url = root.appendingPathComponent(draft.path.value)
        let original = try Data(contentsOf: url)
        model.store = VaultStore(root: root, fileSystem: WriteRejectingFileSystem())
        draft.title = "Retry title"
        draft.notes = "Retry notes"
        #expect(await !(model.flushTaskChanges()))
        #expect(try Data(contentsOf: url) == original)
        #expect(draft.saveError != nil)
        #expect(draft.isDirty)
        model.store = VaultStore(root: root)
        #expect(await model.flushTaskChanges())
        let saved = try #require(try await VaultStore(root: root).snapshot().projects[draft.path]?.value)
        #expect(saved.title == "Retry title")
        #expect(saved.body == "Retry notes")
    }
}

@MainActor
@Test func projectDraftKeepsEditsTypedDuringSave() throws {
    let original = try Project(
        path: VaultPath("Projects/A.md"),
        title: "A",
        status: .active,
        createdAt: Date(),
        updatedAt: Date()
    )
    let draft = ProjectDraft(VaultRecord(value: original, revision: FileRevision(data: Data())), session: UUID())
    draft.title = "Saved title"
    let generation = draft.generation
    let saved = try draft.patch().applying(to: original, now: Date())
    draft.notes = "Typed while saving"
    draft.accept(
        VaultRecord(value: saved, revision: FileRevision(data: Data("saved".utf8))),
        savedGeneration: generation
    )
    #expect(draft.notes == "Typed while saving")
    #expect(draft.title == "Saved title")
    #expect(draft.isDirty)
}
