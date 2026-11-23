import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import Testing

@Test func taskTitleMarkdownPreservesInlineStylesAndLinks() throws {
    let source = "Read **carefully** and [visit](https://example.com) with `code`"
    let text = TaskMarkdown.inline(source)
    #expect(String(text.characters) == "Read carefully and visit with code")
    #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
    let link = try #require(text.runs.first { $0.link != nil })
    #expect(link.link?.absoluteString == "https://example.com")
    let row = TaskMarkdown.inline(source, links: false)
    #expect(row.runs.allSatisfy { $0.link == nil })
    #expect(String(row.characters) == String(text.characters))
}

@Test func taskNotesMarkdownRetainsBlockStructure() throws {
    let source = """
    # Heading

    A **bold** paragraph with a [link](https://example.com).

    - First
    - Second

    1. Ordered
    2. Next

    > Quoted

    ```swift
    let value = "**literal**"
    ```
    """
    let blocks = TaskMarkdown.blocks(source)
    #expect(blocks.count == 8)
    #expect(blocks.first?.headingLevel == 1)
    #expect(blocks[1].text.runs.contains { $0.link?.absoluteString == "https://example.com" })
    #expect(blocks[2].listMarker == "•")
    #expect(blocks[3].listMarker == "•")
    #expect(blocks[4].listMarker == "1.")
    #expect(blocks[5].listMarker == "2.")
    #expect(blocks[6].isQuote)
    let code = try #require(blocks.last)
    #expect(code.isCode)
    #expect(String(code.text.characters).contains("**literal**"))
}

@Test func taskMarkdownKeepsWhitespaceAndIncompleteInputReadable() {
    let source = "First  line\nSecond **unfinished [link]("
    #expect(String(TaskMarkdown.inline(source).characters) == source)
    #expect(TaskMarkdown.blocks("").isEmpty)
}

@Test func taskNotesPreviewKeepsInteractiveChecklistsInDocumentOrder() throws {
    let source = "Résumé 🧪\r\n\r\n- [ ] **First** step\r\n- Ordinary item\r\n1. [X] Second step\r\n"
        + "\r\n```md\r\n- [ ] Literal\r\n```\r\n"
    let checklist = MarkdownChecklist(source)
    let blocks = TaskMarkdown.blocks(source, checklist: checklist)

    #expect(blocks.compactMap(\.checklistItem) == checklist.items)
    #expect(blocks.map { String($0.text.characters).trimmingCharacters(in: .newlines) } == [
        "Résumé 🧪", "First step", "Ordinary item", "Second step", "- [ ] Literal",
    ])
    #expect(blocks[1].text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    let first = try #require(blocks[1].checklistItem)
    #expect(try checklist.settingChecked(true, item: first) == source.replacingOccurrences(
        of: "[ ] **",
        with: "[x] **"
    ))
}

@Test func taskNotesKeepChecklistMarkersSeparateFromReferenceLinks() {
    let source = "Intro\n3. [X] **Third**\n\n- [x] [Reference][x]\n\n[x]: https://example.com\n"
    let checklist = MarkdownChecklist(source)
    let blocks = TaskMarkdown.blocks(source, checklist: checklist)
    #expect(blocks.map { String($0.text.characters) } == ["Intro", "Third", "Reference"])
    #expect(blocks.compactMap(\.checklistItem) == checklist.items)
    #expect(blocks.last?.text.runs.first?.link?.absoluteString == "https://example.com")
}

@Test func taskNotesPreviewRendersTablesRulesAndImages() throws {
    let source = """
    ## Plan

    ![Diagram](figures/plan.png)

    ---

    | Phase | Time |
    | :---- | ---: |
    | **Draft** | 10m |
    | Review | |
    """
    let blocks = TaskMarkdown.blocks(source)
    let elements = TaskMarkdown.elements(in: blocks)
    #expect(blocks[0].headingLevel == 2)
    #expect(blocks[1].text.runs.first?.imageURL?.relativeString == "figures/plan.png")
    #expect(blocks[2].isThematicBreak)
    #expect(elements.count == 4)
    let last = try #require(elements.last)
    guard case let .table(table) = last else {
        Issue.record("Expected a table after the rule")
        return
    }
    #expect(table.columns.map(\.alignment) == [.left, .right])
    #expect(table.rows.map(\.isHeader) == [true, false, false])
    #expect(table.rows[1].cells[0]?.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
    #expect(table.rows[2].cells[1]?.characters.isEmpty ?? true)
}

@Test func taskNotesResolveRelativeImagesOnlyInsideTheVault() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("escape"),
        withDestinationURL: root.deletingLastPathComponent()
    )
    let context = TaskMarkdownImageContext(vault: root, taskPath: "Tasks/Example.md")
    let image = try #require(URL(string: "../Images/a%20b.png"))
    let resolved = try #require(context.localImageURL(image))
    #expect(resolved.path == root.resolvingSymlinksInPath().appendingPathComponent("Images/a b.png").path)
    for destination in [
        "../../outside.png",
        "../.config/icon.png",
        "../escape/picture.png",
        "file:///tmp/outside.png",
    ] {
        #expect(try context.localImageURL(#require(URL(string: destination))) == nil, "\(destination)")
    }
}

@Test func taskListRowsUseTheHeaderContentInset() {
    #expect(TaskListLayout.rowInsets.leading == TaskListLayout.contentHorizontalInset)
    #expect(TaskListLayout.contentHorizontalInset == 28)
}

@MainActor
@Test func markdownTaskEditsRoundTripWithoutRenderingIntoStorage() async throws {
    try await withWorkspace { model, _ in
        let title = "Review **design** at [example](https://example.com)"
        await model.createTask(title: title, vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        let notes = "# Plan\n\nVisit [docs](https://example.com/docs).\n\n- [ ] **Read** docs\n"
        draft.notes = notes
        _ = TaskMarkdown.inline(draft.title)
        _ = TaskMarkdown.blocks(draft.notes)
        #expect(await model.flushTaskChanges())
        let store = try #require(model.store)
        let snapshot = try await store.snapshot()
        let saved = try #require(snapshot.tasks[draft.path]?.value)
        #expect(saved.title == title)
        #expect(saved.body == notes)
    }
}
