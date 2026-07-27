import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func taskDocumentDecodesEveryKnownField() throws {
    let document = try MarkdownDocument.parse(fixture(named: "recurring-task"))
    let path = try VaultPath("Tasks/Weekly review.md")

    guard case let .task(task) = try EntityDocumentCodec.decode(document, at: path) else {
        Issue.record("Expected task entity")
        return
    }
    let scheduled = try CalendarDate("2026-07-27")
    let deadline = try CalendarDate("2026-07-31")

    #expect(task.title == "Weekly review")
    #expect(task.priority == .p1)
    #expect(task.scheduled == scheduled)
    #expect(task.deadline == deadline)
    #expect(task.project?.value == "Projects/Local Todo.md")
    #expect(task.area?.value == "Areas/Personal Systems.md")
    #expect(task.tags == ["review"])
    guard case let .fixed(rule) = task.recurrence else {
        Issue.record("Expected fixed recurrence")
        return
    }
    #expect(rule.frequency == .weekly)
    #expect(rule.interval == 2)
    #expect(rule.weekdays == [.monday, .friday])
}

@Test func projectAndAreaDocumentsDecode() throws {
    let projectDocument = try MarkdownDocument.parse(fixture(named: "valid-project"))
    let areaDocument = try MarkdownDocument.parse(fixture(named: "valid-area"))

    guard case let .project(project) = try EntityDocumentCodec.decode(
        projectDocument,
        at: VaultPath("Projects/Local Todo.md")
    ) else {
        Issue.record("Expected project entity")
        return
    }
    guard case let .area(area) = try EntityDocumentCodec.decode(
        areaDocument,
        at: VaultPath("Areas/Personal Systems.md")
    ) else {
        Issue.record("Expected area entity")
        return
    }

    #expect(project.area?.value == "Areas/Personal Systems.md")
    #expect(project.tags == ["software"])
    #expect(area.title == "Personal Systems")
    #expect(area.tags == ["home"])
}

@Test func typedEncodingPreservesUnknownProjectFields() throws {
    let source = try fixture(named: "valid-project")
    let original = try MarkdownDocument.parse(source)
    guard case let .project(project) = try EntityDocumentCodec.decode(
        original,
        at: VaultPath("Projects/Local Todo.md")
    ) else {
        Issue.record("Expected project entity")
        return
    }
    var patch = ProjectPatch()
    patch.title = .set("Local Todo V1")
    let updated = try patch.applying(to: project, now: Date(timeIntervalSince1970: 1_774_608_060))

    let rendered = try EntityDocumentCodec.encode(.project(updated), preserving: original).rendered()
    let reparsed = try MarkdownDocument.parse(rendered)

    #expect(reparsed.string(forKey: "title") == "Local Todo V1")
    #expect(reparsed.string(forKey: "plugin_owner") == "external-agent")
    #expect(reparsed.body == original.body)
}

@Test func afterCompletionRecurrenceRoundTrips() throws {
    let interval = try RecurrenceInterval(value: 3, unit: .day)
    let task = try TodoTask(
        path: VaultPath("Tasks/Water plants.md"),
        title: "Water plants",
        status: .next,
        recurrence: .afterCompletion(interval),
        createdAt: Date(timeIntervalSince1970: 1_774_608_000),
        updatedAt: Date(timeIntervalSince1970: 1_774_608_000)
    )

    let document = try EntityDocumentCodec.encode(.task(task))
    let reparsed = try MarkdownDocument.parse(document.rendered())
    guard case let .task(decoded) = try EntityDocumentCodec.decode(reparsed, at: task.path) else {
        Issue.record("Expected task entity")
        return
    }

    #expect(decoded.recurrence == .afterCompletion(interval))
}

@Test func entityDecodeReportsMissingAndInvalidFields() throws {
    let missing = try MarkdownDocument.parse("---\ntype: task\ntitle: Missing status\n---\n")
    #expect(throws: EntityDocumentError.missingField("status")) {
        try EntityDocumentCodec.decode(missing, at: VaultPath("Tasks/Missing.md"))
    }

    let invalid = try MarkdownDocument.parse(
        """
        ---
        type: area
        title: Area
        status: unknown
        created_at: 2026-07-27T09:00:00Z
        updated_at: 2026-07-27T09:00:00Z
        ---

        """
    )
    #expect(throws: EntityDocumentError.invalidField("status")) {
        try EntityDocumentCodec.decode(invalid, at: VaultPath("Areas/Invalid.md"))
    }
}
