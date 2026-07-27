import ArgumentParser
import Foundation
@testable import LocalTodoCLI
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func initCommandCreatesManifest() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-init-tests-\(UUID().uuidString)")
    defer { removeCLITestVault(root) }
    let command = try InitCommand.parse([root.path, "--timezone", "Europe/London"])

    try command.run()

    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(LocalTodoSchema.manifestPath).path))
}

@Test func commandsCreateAndCompleteReferencedTask() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let area = try AreaAddCommand.parse([
        "--vault", root.path,
        "Areas/Work.md", "--title", "Work",
    ])
    let project = try ProjectAddCommand.parse([
        "--vault", root.path,
        "Projects/App.md", "--title", "App", "--area", "Areas/Work.md",
    ])
    let task = try AddCommand.parse([
        "--vault", root.path,
        "Tasks/Ship.md", "--title", "Ship V1", "--status", "next",
        "--project", "Projects/App.md", "--area", "Areas/Work.md", "--priority", "p1",
    ])

    try await area.run()
    try await project.run()
    try await task.run()
    let complete = try CompleteCommand.parse(["--vault", root.path, "Tasks/Ship.md"])
    try await complete.run()

    let snapshot = try await VaultStore(root: root).snapshot()
    let path = try VaultPath("Tasks/Ship.md")
    #expect(snapshot.tasks[path]?.value.status == .done)
    #expect(snapshot.tasks[path]?.value.priority == .p1)
    #expect(snapshot.diagnostics.isEmpty)
}

@Test func dryRunDoesNotWriteTask() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let command = try AddCommand.parse([
        "--vault", root.path, "--dry-run",
        "Tasks/Preview.md", "--title", "Preview",
    ])

    try await command.run()

    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Tasks/Preview.md").path))
}

@Test func moveCommandUpdatesReferences() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let project = try ProjectAddCommand.parse([
        "--vault", root.path, "Projects/App.md", "--title", "App",
    ])
    let task = try AddCommand.parse([
        "--vault", root.path, "Tasks/Ship.md", "--title", "Ship", "--project", "Projects/App.md",
    ])
    try await project.run()
    try await task.run()
    let move = try MoveCommand.parse([
        "--vault", root.path, "Projects/App.md", "Projects/Renamed.md",
    ])

    try await move.run()

    let snapshot = try await VaultStore(root: root).snapshot()
    let taskPath = try VaultPath("Tasks/Ship.md")
    #expect(snapshot.tasks[taskPath]?.value.project?.value == "Projects/Renamed.md")
}
