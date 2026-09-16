import Foundation
import LocalTodoDomain
@testable import LocalTodoMarkdown
import Testing

@Test(arguments: [false, true])
func recurrenceEditsPreserveUnknownNestedFrontmatter(changeMode: Bool) throws {
    let source = """
    ---
    type: task
    title: Repeat
    status: next
    created_at: 2026-09-16T12:00:00Z
    updated_at: 2026-09-16T12:00:00Z
    recurrence:
      mode: fixed
      rule: FREQ=WEEKLY;BYDAY=MO
      plugin:
        labels: [keep, me]
        enabled: true
    ---
    Notes
    - [X] Keep checked
    """
    let original = try MarkdownDocument.parse(source)
    let path = try VaultPath("Tasks/Repeat.md")
    guard case let .task(task) = try EntityDocumentCodec.decode(original, at: path) else {
        Issue.record("Expected task")
        return
    }
    var patch = TaskPatch()
    patch.title = .set("Updated")
    if changeMode {
        patch.recurrence = try .set(.afterCompletion(RecurrenceInterval(value: 3, unit: .day)))
    }
    let updated = try patch.applying(to: task, now: Date())
    let encoded = try EntityDocumentCodec.encode(.task(updated), preserving: original)
    let decoded = try MarkdownDocument.parse(encoded.rendered())
    #expect(decoded.node(forKey: "recurrence")?["plugin"] == original.node(forKey: "recurrence")?["plugin"])
    #expect(decoded.body == original.body)
    if changeMode {
        #expect(decoded.node(forKey: "recurrence")?["rule"] == nil)
        #expect(decoded.node(forKey: "recurrence")?["interval"]?.scalar?.string == "P3D")
    }
}
