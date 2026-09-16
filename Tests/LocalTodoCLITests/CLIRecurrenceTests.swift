import Foundation
@testable import LocalTodoCLI
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test(arguments: [false, true])
func cliRepeatPersistsChecklistPreferenceAndPreservesNotes(afterCompletion: Bool) async throws {
    let root = try makeCLITestVault()
    defer { removeCLITestVault(root) }
    let path = try VaultPath("Tasks/Repeat.md")
    let body = "# Notes 🦊\r\n- [X] Done\r\n```\r\n- [x] Code\r\n```\r\n"
    let recurrence = afterCompletion ? ["--repeat-after", "P3D"] : ["--repeat-rule", "FREQ=DAILY"]
    try await AddCommand.parse([
        "--vault", root.path, path.value, "--title", "Repeat", "--scheduled", "2020-01-01",
        "--deadline", "2020-01-03", "--body", body, "--reset-checklist-on-repeat",
    ] + recurrence).run()
    let url = root.appendingPathComponent(path.value)
    let original = try String(contentsOf: url, encoding: .utf8)
        .replacingOccurrences(of: "type: task", with: "type: task\nplugin_value: [keep, me]")
    try Data(original.utf8).write(to: url)
    try await CompleteCommand.parse(["--vault", root.path, "--dry-run", path.value]).run()
    #expect(try String(contentsOf: url, encoding: .utf8) == original)
    try await CompleteCommand.parse(["--vault", root.path, path.value]).run()
    let snapshot = try await VaultStore(root: root).snapshot()
    let saved = try #require(snapshot.tasks[path]?.value)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
    let today = try CalendarDate(date: Date(), calendar: calendar)
    #expect(try saved.scheduled == today.adding(DateComponents(day: afterCompletion ? 3 : 1), calendar: calendar))
    #expect(try saved.deadline == saved.scheduled?.adding(DateComponents(day: 2), calendar: calendar))
    #expect(saved.body == body.replacingOccurrences(of: "[X]", with: "[ ]"))
    #expect(saved.resetChecklistOnRepeat)
    #expect(try MarkdownDocument.parse(String(contentsOf: url, encoding: .utf8))
        .strings(forKey: "plugin_value") == ["keep", "me"])
    try await EditCommand.parse([
        "--vault", root.path, path.value, "--reset-checklist-on-repeat", "false", "--body", body,
    ]).run()
    try await CompleteCommand.parse(["--vault", root.path, path.value]).run()
    let disabled = try #require(try await VaultStore(root: root).snapshot().tasks[path]?.value)
    #expect(!disabled.resetChecklistOnRepeat)
    #expect(disabled.body == body)
}
