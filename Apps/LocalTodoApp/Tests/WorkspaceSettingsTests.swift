import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func changingTimezoneUpdatesTodayAndPersistsForOtherClients() async throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-09-17T00:30:00Z"))
    try await withWorkspace(now: now) { model, root in
        await model.createTask(title: "Tomorrow in Los Angeles", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.scheduled = "2026-09-17"
        #expect(await model.flushTaskChanges())
        model.route = .today
        #expect(model.visibleTasks.count == 1)
        await model.setVaultTimezone("America/Los_Angeles")
        #expect(model.visibleTasks.isEmpty)
        #expect(model.configurationSettingsError == nil)
        #expect(try await VaultStore(root: root).snapshot().configuration.timezone == "America/Los_Angeles")
        await model.setVaultTimezone(nil)
        #expect(try await VaultStore(root: root).configurationRecord().value.timezone == nil)
    }
}

@MainActor
@Test func timezoneFailureAndPendingDraftsLeaveManifestUntouched() async throws {
    try await withWorkspace { model, root in
        let manifest = root.appendingPathComponent(LocalTodoSchema.manifestPath)
        let original = try Data(contentsOf: manifest)
        await model.createTask(title: "Pending", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        draft.scheduled = "invalid date"
        await model.setVaultTimezone("Asia/Tokyo")
        #expect(model.configurationSettingsError != nil)
        #expect(try Data(contentsOf: manifest) == original)
        model.discardChanges(for: draft.path)
        model.store = VaultStore(root: root, fileSystem: WriteRejectingFileSystem())
        await model.setVaultTimezone("Asia/Tokyo")
        #expect(model.configurationSettingsError != nil)
        #expect(!model.isSavingConfiguration)
        #expect(try Data(contentsOf: manifest) == original)
    }
}

@MainActor
@Test func timezoneChangePreservesDeletedTaskRecovery() async throws {
    try await withWorkspace { model, root in
        await model.createTask(title: "Recover after settings", vaultSession: model.vaultSession)
        let path = try #require(model.selectedTaskPath)
        let url = root.appendingPathComponent(path.value)
        let original = try Data(contentsOf: url)
        let undo = UndoManager()
        undo.groupsByEvent = false
        model.setUndoManager(undo)
        undo.beginUndoGrouping()
        await model.deleteTask(at: path)
        undo.endUndoGrouping()
        await model.setVaultTimezone("Asia/Tokyo")
        #expect(undo.canUndo)
        model.performUndo()
        #expect(await model.flushTaskChanges())
        #expect(try Data(contentsOf: url) == original)
        #expect(model.snapshot?.configuration.timezone == "Asia/Tokyo")
    }
}
