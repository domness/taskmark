import Foundation

/// Read-only presentation; never serialize this projection back into a task.
enum MobileTaskMarkdown {
    static func inline(_ source: String) -> AttributedString {
        do {
            var text = try AttributedString(
                markdown: source,
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
            text.link = nil
            return text
        } catch {
            // Incomplete or unsupported Markdown must remain readable and editable.
            return AttributedString(source)
        }
    }
}
