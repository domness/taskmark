import Foundation
@testable import LocalTodoIOSApp
import Testing

@MainActor
struct MobileSampleVaultTests {
    @Test func sampleOpensAndRestoresCanonicalEdits() async throws {
        let name = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let bookmarks = MobileVaultBookmarkStore(defaults: defaults)
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let root = parent.appendingPathComponent("Sample Vault")
        let workspace = MobileWorkspace(bookmarks: bookmarks, sampleVaultURL: root)
        let restored = MobileWorkspace(bookmarks: bookmarks, sampleVaultURL: root)
        defer {
            workspace.suspendProviderObservation()
            restored.suspendProviderObservation()
            workspace.session.release()
            restored.session.release()
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: parent)
        }
        await workspace.openSampleVault()
        #expect(workspace.errorMessage == nil)
        #expect(workspace.snapshot?.tasks.count == 14)
        #expect(workspace.vaultName == "Sample Vault")
        _ = try await workspace.session.capture(title: "My sample note", route: .today)
        await restored.restoreVault()
        #expect(restored.tasks(for: .today).contains { $0.title == "My sample note" })
        #expect(restored.snapshot?.diagnostics.isEmpty == true)
        #expect(restored.session.savedFilters.filters.count == 1)
    }
}
