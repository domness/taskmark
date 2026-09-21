import Foundation
@testable import LocalTodoApp
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
