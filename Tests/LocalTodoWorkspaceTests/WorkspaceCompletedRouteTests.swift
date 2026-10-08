import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
@testable import LocalTodoWorkspace
import Testing

@MainActor
struct WorkspaceCompletedRouteTests {
    @Test func completedRouteIncludesDoneTasksAndExcludesCanceledTasks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try VaultInitializer.initialize(at: root, timezone: "Europe/London")
        let session = WorkspaceSession()
        try await session.open(root: root)
        let done = try await session.capture(title: "Done", route: .inbox)
        let canceled = try await session.capture(title: "Canceled", route: .inbox)
        try await session.toggleCompletion(at: done)
        var patch = TaskPatch()
        patch.status = .set(.canceled)
        try await session.updateTask(at: canceled, patch: patch)

        #expect(session.tasks(for: .completed).map(\.path) == [done])
    }
}
