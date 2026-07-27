import Foundation
@testable import LocalTodoApp
import LocalTodoMarkdown
import Testing

@MainActor
@Test func workspaceCreatesAndRemembersVault() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-app-vault-tests-\(UUID().uuidString)")
    let suiteName = "LocalTodoAppTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let bookmarks = VaultBookmarkStore(defaults: defaults)
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    do {
        let model = WorkspaceModel(bookmarks: bookmarks)
        await model.createVault(at: root)
        #expect(model.errorMessage == nil)
        #expect(model.snapshot?.configuration.schema == LocalTodoSchema.currentVersion)
    }
    #expect(
        FileManager.default.fileExists(
            atPath: root.appendingPathComponent(LocalTodoSchema.manifestPath).path
        )
    )
    #expect(try bookmarks.restore()?.standardizedFileURL == root.standardizedFileURL)

    let restoredModel = WorkspaceModel(bookmarks: bookmarks)
    await restoredModel.restoreVault()

    #expect(restoredModel.errorMessage == nil)
    #expect(restoredModel.rootURL?.standardizedFileURL == root.standardizedFileURL)
}
