import Foundation
import LocalTodoDomain
import Testing

@Test func checklistChangesOnlyTheSelectedMarker() throws {
    let body = "# Notes 🦊\r\n\r\n- [ ] First\r\n  * [X] Nested\r\n1. [x] Ordered\r\n+ [ ] Last"
    let checklist = MarkdownChecklist(body)
    #expect(checklist.items.map(\.title) == ["First", "Nested", "Ordered", "Last"])
    #expect(checklist.items.map(\.isChecked) == [false, true, true, false])
    let updated = try checklist.settingChecked(true, item: #require(checklist.items.first))
    #expect(updated == body.replacingOccurrences(of: "[ ] First", with: "[x] First"))
    #expect(checklist.resetting() == body.replacingOccurrences(of: "[X]", with: "[ ]")
        .replacingOccurrences(of: "[x]", with: "[ ]"))
}

@Test func checklistIgnoresCodeCommentsQuotesAndNonChecklistText() {
    let body = """
    Inline [x] text
    > - [x] Quote
        - [x] Indented code
    ```markdown
    - [x] Fenced code
    ````
    ~~~~
    - [x] Other fence
    ~~~~
    <!--
    - [x] Comment
    -->
    - [x]no separator
    - [z] Invalid
    \\- [x] Escaped
    - [x] Real
    """
    let checklist = MarkdownChecklist(body)
    #expect(checklist.items.map(\.title) == ["Real"])
    #expect(checklist.resetting() == body.replacingOccurrences(of: "[x] Real", with: "[ ] Real"))
}

@Test func checklistRejectsAnItemFromAnotherProjection() throws {
    let item = try #require(MarkdownChecklist("- [x] Old").items.first)
    #expect(throws: DomainValidationError.invalidChecklistItem) {
        try MarkdownChecklist("New text").settingChecked(false, item: item)
    }
}

@Test(arguments: [false, true])
func recurrenceResetsChecklistsOnlyWhenEnabled(enabled: Bool) throws {
    var patch = TaskPatch()
    patch.resetChecklistOnRepeat = .set(enabled)
    let body = "Notes\r\n- [X] Done\r\n```\r\n- [x] Code\r\n```\r\n"
    let task = try patch.applying(to: makeTask(
        recurrence: .afterCompletion(RecurrenceInterval(value: 3, unit: .day)), body: body
    ), now: testNow)
    let next = try TaskTransition.complete(
        task, now: testNow, today: CalendarDate("2026-07-27"), calendar: testCalendar()
    )
    #expect(next.body == (enabled ? body.replacingOccurrences(of: "[X]", with: "[ ]") : body))
    #expect(next.resetChecklistOnRepeat == enabled)
    patch.recurrence = .set(nil)
    let oneOff = try patch.applying(to: task, now: testNow)
    let done = try TaskTransition.complete(
        oneOff, now: testNow, today: CalendarDate("2026-07-27"), calendar: testCalendar()
    )
    #expect(done.body == body)
}
