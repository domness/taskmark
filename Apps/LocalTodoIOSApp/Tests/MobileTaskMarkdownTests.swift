import Foundation
@testable import LocalTodoIOSApp
import Testing

@Test func mobileTaskTitleMarkdownPreservesInlineFormatting() {
    let source = "Review **carefully** with `code` and [docs](https://example.com)"
    let text = MobileTaskMarkdown.inline(source)

    #expect(String(text.characters) == "Review carefully with code and docs")
    #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
    #expect(text.runs.allSatisfy { $0.link == nil })
}

@Test func mobileTaskTitleMarkdownKeepsIncompleteSourceReadable() {
    let source = "First  line\nSecond **unfinished [link]("
    #expect(String(MobileTaskMarkdown.inline(source).characters) == source)
}
