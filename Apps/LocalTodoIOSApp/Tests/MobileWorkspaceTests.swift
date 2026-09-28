import Foundation
import LocalTodoDomain
@testable import LocalTodoIOSApp
import LocalTodoMarkdown
import Testing

@MainActor
struct MobileWorkspaceTests {
    @Test func emptyWorkspaceStartsWithoutCanonicalData() throws {
        let suite = try #require(UserDefaults(suiteName: UUID().uuidString))
        let workspace = MobileWorkspace(bookmarks: MobileVaultBookmarkStore(defaults: suite))
        #expect(workspace.snapshot == nil)
        #expect(workspace.tasks.isEmpty)
    }

    @Test func bookmarkRoundTripsLocalDirectory() throws {
        let suite = try #require(UserDefaults(suiteName: UUID().uuidString))
        let store = MobileVaultBookmarkStore(defaults: suite)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try store.save(url)
        #expect(try store.restore()?.standardizedFileURL == url.standardizedFileURL)
    }
}
