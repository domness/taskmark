import Foundation
import LocalTodoMarkdown
import Testing

@Test func markdownDocumentParsesKnownAndUnknownFields() throws {
    let source = try fixture(named: "valid-task")

    let document = try MarkdownDocument.parse(source)

    #expect(document.string(forKey: "type") == "task")
    #expect(document.string(forKey: "title") == "Review local-first schema")
    #expect(document.strings(forKey: "tags") == ["design", "local-first"])
    #expect(document.string(forKey: "plugin_owner") == "external-agent")
    #expect(document.body.contains("Preserve the thematic break above"))
}

@Test func knownFieldUpdatePreservesUnknownFieldsAndBody() throws {
    let source = try fixture(named: "valid-task")
    var document = try MarkdownDocument.parse(source)
    let originalBody = document.body

    document.set(.string("Review the round-trip contract"), for: .title)
    let rendered = try document.rendered()
    let reparsed = try MarkdownDocument.parse(rendered)

    #expect(reparsed.string(forKey: "title") == "Review the round-trip contract")
    #expect(reparsed.string(forKey: "plugin_owner") == "external-agent")
    #expect(reparsed.string(forKey: "plugin") == nil)
    #expect(reparsed.body == originalBody)
    #expect(rendered.contains("estimate: 3"))
    #expect(rendered.contains("source: imported"))
}

@Test func markdownDocumentRejectsMalformedYAML() throws {
    let source = try fixture(named: "malformed-yaml")

    #expect(throws: MarkdownDocumentError.malformedFrontmatter) {
        try MarkdownDocument.parse(source)
    }
}

@Test func markdownDocumentRejectsMissingClosingDelimiter() throws {
    let source = try fixture(named: "missing-closing-delimiter")

    #expect(throws: MarkdownDocumentError.missingClosingDelimiter) {
        try MarkdownDocument.parse(source)
    }
}

@Test func markdownDocumentRejectsNonMappingFrontmatter() throws {
    let source = try fixture(named: "sequence-frontmatter")

    #expect(throws: MarkdownDocumentError.frontmatterMustBeMapping) {
        try MarkdownDocument.parse(source)
    }
}

@Test func markdownDocumentRejectsMissingOpeningDelimiter() {
    let source = "type: task\ntitle: No frontmatter delimiters\n"

    #expect(throws: MarkdownDocumentError.missingOpeningDelimiter) {
        try MarkdownDocument.parse(source)
    }
}

@Test func knownFieldUpdatePreservesCarriageReturnLineFeedBody() throws {
    let source = "---\r\ntype: task\r\ntitle: Original\r\nstatus: inbox\r\n---\r\n\r\nFirst line\r\nSecond line\r\n"
    var document = try MarkdownDocument.parse(source)
    let originalBody = document.body

    document.set(.string("Updated"), for: .title)
    let rendered = try document.rendered()
    let reparsed = try MarkdownDocument.parse(rendered)

    #expect(reparsed.body == originalBody)
    #expect(rendered.hasSuffix("\r\n\r\nFirst line\r\nSecond line\r\n"))
}

@Test func frontmatterUpdatesSupportListsNullAndRemoval() throws {
    let source = try fixture(named: "valid-task")
    var document = try MarkdownDocument.parse(source)

    document.set(.strings(["storage", "regression"]), for: .tags)
    document.set(.null, for: .priority)
    document.set(.remove, for: .completedAt)
    let rendered = try document.rendered()
    let reparsed = try MarkdownDocument.parse(rendered)

    #expect(reparsed.strings(forKey: "tags") == ["storage", "regression"])
    #expect(rendered.contains("priority: null"))
    #expect(!rendered.contains("completed_at:"))
}

private func fixture(named name: String) throws -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: "md") else {
        throw FixtureError.missing(name)
    }
    return try String(contentsOf: url, encoding: .utf8)
}

private enum FixtureError: Error {
    case missing(String)
}
