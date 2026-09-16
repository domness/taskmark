import Foundation
@testable import LocalTodoCLI
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func cliReschedulePersistsPairedDatesAndSupportsDryRun() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let path = try VaultPath("Tasks/Plan.md")
    try await AddCommand.parse([
        "--vault", root.path, path.value, "--title", "Plan", "--status", "waiting",
        "--scheduled", "2026-03-28", "--deadline", "2026-03-31", "--body", "Notes\r\n- [X] Keep\r\n",
    ]).run()
    let url = root.appendingPathComponent(path.value)
    let original = try String(contentsOf: url, encoding: .utf8)
        .replacingOccurrences(of: "type: task", with: "type: task\nplugin: keep")
    try Data(original.utf8).write(to: url)
    let args = ["--vault", root.path, path.value, "--to", "2026-03-30"]
    try await RescheduleCommand.parse(args + ["--dry-run"]).run()
    #expect(try String(contentsOf: url, encoding: .utf8) == original)
    try await RescheduleCommand.parse(args).run()
    let saved = try #require(try await VaultStore(root: root).snapshot().tasks[path]?.value)
    #expect(saved.scheduled?.description == "2026-03-30")
    #expect(saved.deadline?.description == "2026-04-02")
    #expect(saved.status == .waiting)
    #expect(saved.body == "Notes\r\n- [X] Keep\r\n")
    #expect(try MarkdownDocument.parse(String(contentsOf: url, encoding: .utf8)).string(forKey: "plugin") == "keep")
    let bytes = try Data(contentsOf: url)
    await #expect(throws: (any Error).self) {
        try await RescheduleCommand.parse(["--vault", root.path, path.value, "--to", "invalid"]).run()
    }
    #expect(try Data(contentsOf: url) == bytes)
}
