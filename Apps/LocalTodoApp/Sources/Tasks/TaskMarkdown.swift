import Foundation

/// Read-only presentation; never serialize this projection back into a task.
enum TaskMarkdown {
    static func inline(_ source: String, links: Bool = true) -> AttributedString {
        var text = parse(source, syntax: .inlineOnlyPreservingWhitespace)
        if !links {
            text.link = nil
        }
        return text
    }

    static func blocks(_ source: String) -> [Block] {
        let text = parse(source, syntax: .full)
        var blocks: [Block] = []
        for run in text.runs {
            let content = AttributedString(text[run.range])
            if let last = blocks.indices.last, blocks[last].intent == run.presentationIntent {
                blocks[last].text.append(content)
            } else {
                blocks.append(Block(id: blocks.count, text: content, intent: run.presentationIntent))
            }
        }
        return blocks
    }

    private static func parse(
        _ source: String,
        syntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax
    ) -> AttributedString {
        do {
            return try AttributedString(
                markdown: source,
                options: .init(interpretedSyntax: syntax, failurePolicy: .returnPartiallyParsedIfPossible)
            )
        } catch {
            // Incomplete or unsupported Markdown must remain readable and editable.
            return AttributedString(source)
        }
    }

    struct Block: Identifiable {
        let id: Int
        var text: AttributedString
        let intent: PresentationIntent?

        var headingLevel: Int? {
            for component in intent?.components ?? [] {
                if case let .header(level) = component.kind {
                    return level
                }
            }
            return nil
        }

        var isCode: Bool {
            intent?.components.contains {
                if case .codeBlock = $0.kind {
                    return true
                }
                return false
            } ?? false
        }

        var isQuote: Bool {
            intent?.components.contains { $0.kind == .blockQuote } ?? false
        }

        var listMarker: String? {
            let components = intent?.components ?? []
            for component in components {
                if case let .listItem(ordinal) = component.kind {
                    let list = components.first { $0.kind == .orderedList || $0.kind == .unorderedList }
                    return list?.kind == .orderedList ? "\(ordinal)." : "•"
                }
            }
            return nil
        }

        var listDepth: Int {
            intent?.components.filter {
                $0.kind == .orderedList || $0.kind == .unorderedList
            }.count ?? 0
        }
    }
}
