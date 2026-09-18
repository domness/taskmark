import Foundation
@testable import LocalTodoApp
import LocalTodoMarkdown
import Testing

@MainActor
@Test func preferencesTypedDuringSaveRemainPendingAndThenPersist() async throws {
    try await withWorkspace { model, root in
        let fileSystem = PausingCreationFileSystem(operation: .replace)
        defer { fileSystem.release() }
        model.store = VaultStore(root: root, fileSystem: fileSystem)
        model.preferences.theme = .forest
        let save = Task { await model.flushPreferences() }
        try await awaitPreferencePause(fileSystem)
        model.preferences.theme = .sand
        fileSystem.release()
        _ = await save.value
        #expect(model.preferences.theme == .sand)
        #expect(model.preferenceConflicts.isEmpty)
        #expect(await model.flushPreferences())
        #expect(try await VaultStore(root: root).configurationRecord().value.preferences["theme"] == .string("sand"))
    }
}

@MainActor
@Test func discardingPreferencesDoesNotEraseNewerEdits() async throws {
    try await withWorkspace { model, root in
        let fileSystem = PausingCreationFileSystem(operation: .read)
        defer { fileSystem.release() }
        model.store = VaultStore(root: root, fileSystem: fileSystem)
        model.preferences.theme = .forest
        let discard = Task { await model.discardPreferenceChanges() }
        try await awaitPreferencePause(fileSystem)
        model.preferences.theme = .sand
        fileSystem.release()
        await discard.value
        #expect(model.preferences.theme == .sand)
        #expect(!model.pendingPreferenceChanges.isEmpty)
        #expect(await model.flushPreferences())
    }
}

@MainActor
private func awaitPreferencePause(_ fileSystem: PausingCreationFileSystem) async throws {
    for _ in 0 ..< 100 where !fileSystem.hasPaused {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(fileSystem.hasPaused)
}
