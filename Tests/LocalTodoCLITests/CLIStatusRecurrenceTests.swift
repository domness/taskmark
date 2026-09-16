import Foundation
@testable import LocalTodoCLI
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test(arguments: [false, true])
func cliStatusCompletionUsesTheEditedRecurrence(afterCompletion: Bool) async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let path = try VaultPath("Tasks/Repeat.md")
    try await AddCommand.parse([
        "--vault", root.path, path.value, "--title", "Repeat", "--scheduled", "2020-01-01",
        "--deadline", "2020-01-03", "--body", "Notes\r\n- [X] Done\r\n",
    ]).run()
    let rule = afterCompletion ? ["--repeat-after", "P3D"] : ["--repeat-rule", "FREQ=DAILY"]
    try await EditCommand.parse([
        "--vault", root.path, path.value, "--status", "done", "--reset-checklist-on-repeat", "true",
    ] + rule).run()
    let snapshot = try await VaultStore(root: root).snapshot()
    let saved = try #require(snapshot.tasks[path]?.value)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
    let today = try CalendarDate(date: Date(), calendar: calendar)
    #expect(saved.status == .next)
    #expect(try saved.scheduled == today.adding(DateComponents(day: afterCompletion ? 3 : 1), calendar: calendar))
    #expect(try saved.deadline == saved.scheduled?.adding(DateComponents(day: 2), calendar: calendar))
    #expect(saved.body == "Notes\r\n- [ ] Done\r\n")
    let output = EntityOutput(.task(saved), includeBody: true)
    #expect(output.repeatAfter == (afterCompletion ? "P3D" : nil))
    #expect(output.repeatRule == (afterCompletion ? nil : "FREQ=DAILY"))
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(output)) as? [String: Any])
    #expect(json[afterCompletion ? "repeat_after" : "repeat_rule"] as? String ==
        (afterCompletion ? "P3D" : "FREQ=DAILY"))
}

@Test func cliStatusCompletionCanExplicitlyEndRecurrence() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let path = try VaultPath("Tasks/Finish.md")
    try await AddCommand.parse([
        "--vault", root.path, path.value, "--title", "Finish", "--scheduled", "2026-09-16",
        "--repeat-after", "P3D", "--body=- [X] Keep\n", "--reset-checklist-on-repeat",
    ]).run()
    let args = ["--vault", root.path, path.value, "--status", "done", "--clear-recurrence"]
    let url = root.appendingPathComponent(path.value)
    let before = try Data(contentsOf: url)
    try await EditCommand.parse(args + ["--dry-run"]).run()
    #expect(try Data(contentsOf: url) == before)
    try await EditCommand.parse(args).run()
    let saved = try #require(try await VaultStore(root: root).snapshot().tasks[path]?.value)
    #expect(saved.status == .done)
    #expect(saved.recurrence == nil)
    #expect(saved.scheduled?.description == "2026-09-16")
    #expect(saved.body == "- [X] Keep\n")
}

@Test func cliStatusCompletionRejectsCanceledRecurrenceWithoutWriting() async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let path = "Tasks/Canceled.md"
    try await AddCommand.parse([
        "--vault", root.path, path, "--title", "Canceled", "--status", "canceled", "--repeat-after", "P3D",
    ]).run()
    let url = root.appendingPathComponent(path)
    let bytes = try Data(contentsOf: url)
    await #expect(throws: DomainValidationError.invalidCompletionState) {
        try await EditCommand.parse(["--vault", root.path, path, "--status", "done"]).run()
    }
    #expect(try Data(contentsOf: url) == bytes)
}
