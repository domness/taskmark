import Foundation
@testable import LocalTodoCLI
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func cliProjectEditingAndLifecycleKeepExactPath() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let path = try VaultPath("Projects/Original.md")
    try await ProjectAddCommand.parse(["--vault", root.path, path.value, "--title", "Original"]).run()
    let body = "# Notes\r\nKeep Markdown **intact**.\r\n"
    try await ProjectEditCommand.parse([
        "--vault", root.path, path.value, "--title", "Changed", "--body", body,
    ]).run()
    try await ProjectCompleteCommand.parse(["--vault", root.path, path.value]).run()
    let done = try #require(try await VaultStore(root: root).snapshot().projects[path]?.value)
    #expect(done.status == .done)
    #expect(done.completedAt != nil)
    #expect(done.title == "Changed")
    #expect(done.body == body)
    try await ProjectReopenCommand.parse(["--vault", root.path, path.value]).run()
    let active = try #require(try await VaultStore(root: root).snapshot().projects[path]?.value)
    #expect(active.status == .active)
    #expect(active.completedAt == nil)
    #expect(active.body == body)
}
