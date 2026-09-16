import Foundation
@testable import LocalTodoCLI
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func cliSavesRunsReplacesAndDeletesVaultFilters() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let args = ["--vault", root.path, "Waiting work", "--view", "waiting", "--tag", "work", "--sort", "priority"]
    try await FilterSaveCommand.parse(args + ["--dry-run"]).run()
    #expect(try await VaultStore(root: root).savedFilters().filters.isEmpty)
    try await FilterSaveCommand.parse(args).run()
    let record = try await VaultStore(root: root).savedFilters()
    #expect(record.filters.first?.query.scope == .waiting)
    #expect(record.filters.first?.query.filters.tags == ["work"])
    #expect(record.filters.first?.query.sort == .priority)
    await #expect(throws: (any Error).self) { try await FilterSaveCommand.parse(args).run() }
    try await FilterRunCommand.parse(["--vault", root.path, "Waiting work", "--json"]).run()
    try await FilterSaveCommand.parse(["--vault", root.path, "Waiting work", "--view", "someday", "--replace"]).run()
    #expect(try await VaultStore(root: root).savedFilters().filters.first?.query.scope == .someday)
    try await FilterDeleteCommand.parse(["--vault", root.path, "Waiting work", "--dry-run"]).run()
    #expect(try await VaultStore(root: root).savedFilters().filters.count == 1)
    try await FilterDeleteCommand.parse(["--vault", root.path, "Waiting work"]).run()
    #expect(try await VaultStore(root: root).savedFilters().filters.isEmpty)
}

@Test func savedFilterConflictUsesStableCLIErrorKind() throws {
    let data = try CLIErrorRenderer.data(for: SavedFilterError.conflict, command: "filter save", dryRun: false)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let error = try #require(json["error"] as? [String: Any])
    #expect(error["kind"] as? String == "conflict")
}
