import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test(arguments: ["true", "false", "null", "\"true\"", "\"false\""])
func checklistResetOptionRoundTrips(value: String) throws {
    let source = try fixture(named: "recurring-task")
        .replacingOccurrences(of: "type: task", with: "type: task\nreset_checklist_on_repeat: \(value)")
    let document = try MarkdownDocument.parse(source)
    let path = try VaultPath("Tasks/Repeat.md")
    guard case let .task(task) = try EntityDocumentCodec.decode(document, at: path) else {
        Issue.record("Expected task")
        return
    }
    #expect(task.resetChecklistOnRepeat == value.contains("true"))
    let rendered = try EntityDocumentCodec.encode(.task(task), preserving: document).rendered()
    let decoded = try EntityDocumentCodec.decode(MarkdownDocument.parse(rendered), at: path)
    #expect(decoded == .task(task))
    #expect(try MarkdownDocument.parse(rendered).body == document.body)
}

@Test(arguments: ["[]", "{}", "yes", "1", "TRUE", "sometimes"])
func checklistResetRejectsMalformedValues(value: String) throws {
    let source = try fixture(named: "recurring-task")
        .replacingOccurrences(of: "type: task", with: "type: task\nreset_checklist_on_repeat: \(value)")
    #expect(throws: EntityDocumentError.invalidField("reset_checklist_on_repeat")) {
        try EntityDocumentCodec.decode(MarkdownDocument.parse(source), at: VaultPath("Tasks/Repeat.md"))
    }
}

@Test func checklistResetIsOffForExistingNotes() throws {
    let document = try MarkdownDocument.parse(fixture(named: "recurring-task"))
    guard case let .task(task) = try EntityDocumentCodec.decode(document, at: VaultPath("Tasks/Repeat.md")) else {
        Issue.record("Expected task")
        return
    }
    #expect(!task.resetChecklistOnRepeat)
}
