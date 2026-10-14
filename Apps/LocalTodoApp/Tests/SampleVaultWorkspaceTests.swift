import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
struct SampleVaultWorkspaceTests {
    @Test func sampleOpensRestoresAndRejectsSwitchingWithUnsavedCapture() async throws {
        let name = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let bookmarks = VaultBookmarkStore(defaults: defaults)
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let root = parent.appendingPathComponent("Sample Vault")
        let model = WorkspaceModel(bookmarks: bookmarks, sampleVaultURL: root)
        let restored = WorkspaceModel(bookmarks: bookmarks, sampleVaultURL: root)
        defer {
            model.releaseWindowResources()
            restored.releaseWindowResources()
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: parent)
        }
        await model.openSampleVault()
        #expect(model.errorMessage == nil)
        #expect(model.snapshot?.tasks.count == 14)
        #expect(model.vaultName == "Sample Vault")
        #expect(!model.visibleTasks.isEmpty)
        await model.createTask(title: "My sample note", vaultSession: model.vaultSession, captureRoute: .today)
        await restored.restoreVault()
        #expect(restored.visibleTasks.contains { $0.title == "My sample note" })
        model.beginQuickCapture()
        model.quickCaptureTitle = "Keep this draft"
        let session = model.vaultSession
        await model.openSampleVault()
        #expect(model.vaultSession == session)
        #expect(model.quickCaptureTitle == "Keep this draft")
        #expect(model.errorMessage != nil)
    }
}
