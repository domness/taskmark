import Foundation
import LocalTodoDomain

/// Read-only presentation; never serialize this projection back into a task.
enum TaskMarkdown {
    static func inline(_ source: String, links: Bool = true) -> AttributedString {
        var text = parse(source, syntax: .inlineOnlyPreservingWhitespace)
        if !links {
            text.link = nil
        }
        return text
    }

    static func blocks(_ source: String, checklist: MarkdownChecklist? = nil) -> [Block] {
        guard let checklist, checklist.body == source, !checklist.items.isEmpty else {
            return blocks(in: source, itemsByLine: [:])
        }
        let checklistItems = checklist.items
        let initial = checklistSource(source, items: checklistItems, separateItems: [])
        var blocks = blocks(in: initial.source, itemsByLine: initial.lines)
        var rendered = Set(blocks.compactMap { $0.checklistItem?.id })
        let unmatched = Set(checklistItems.map(\.id)).subtracting(rendered)
        if !unmatched.isEmpty {
            // A non-1 ordered list cannot interrupt a paragraph in CommonMark, but Taskmark
            // recognizes such checklist lines. Give only those lines a new block boundary.
            let retry = checklistSource(source, items: checklistItems, separateItems: unmatched)
            blocks = self.blocks(in: retry.source, itemsByLine: retry.lines)
            rendered = Set(blocks.compactMap { $0.checklistItem?.id })
        }
        for item in checklistItems where !rendered.contains(item.id) {
            blocks.append(Block(id: blocks.count, text: inline(item.title), intent: nil, checklistItem: item))
        }
        return blocks
    }

    private static func checklistSource(
        _ source: String, items: [MarkdownChecklist.Item], separateItems: Set<Int>
    ) -> (source: String, lines: [Int: MarkdownChecklist.Item]) {
        var projected: [UInt8] = []
        var lines: [Int: MarkdownChecklist.Item] = [:]
        var itemIndex = 0
        var byteOffset = 0
        var lineNumber = 1
        for line in source.utf8.split(separator: 10, omittingEmptySubsequences: false) {
            if byteOffset > 0 {
                projected.append(10)
            }
            if itemIndex < items.count, items[itemIndex].id < byteOffset + line.count {
                let item = items[itemIndex]
                if separateItems.contains(item.id) {
                    projected.append(10)
                    lineNumber += 1
                }
                lines[lineNumber] = item
                let start = item.id - byteOffset - 1
                projected += line.prefix(start)
                // Unlike [x], this marker cannot parse as a reference link.
                projected += "☐".utf8
                projected += line.dropFirst(start + 3)
                itemIndex += 1
            } else {
                projected += line
            }
            byteOffset += line.count + 1
            lineNumber += 1
        }
        // All splice points are adjacent to validated ASCII checklist markers/newlines.
        // swiftlint:disable:next optional_data_string_conversion
        return (String(decoding: projected, as: UTF8.self), lines)
    }

    private static func blocks(in source: String, itemsByLine: [Int: MarkdownChecklist.Item]) -> [Block] {
        let text = parse(source, syntax: .full, sourcePositions: !itemsByLine.isEmpty)
        var blocks: [Block] = []
        var seenListItems: Set<Int> = []
        for run in text.runs {
            let content = AttributedString(text[run.range])
            if let last = blocks.indices.last, blocks[last].intent == run.presentationIntent {
                blocks[last].text.append(content)
            } else {
                let listItem = run.presentationIntent?.components.first {
                    if case .listItem = $0.kind {
                        return true
                    }
                    return false
                }
                let showsMarker = listItem.map { seenListItems.insert($0.identity).inserted } ?? false
                let line = run.markdownSourcePosition?.startLine
                let item = showsMarker && content.characters.first == "☐" ? line.flatMap { itemsByLine[$0] } : nil
                blocks.append(Block(
                    id: blocks.count, text: content, intent: run.presentationIntent,
                    showsMarker: showsMarker, checklistItem: item
                ))
            }
        }
        for index in blocks.indices where blocks[index].checklistItem != nil {
            let label = blocks[index].text.characters.dropFirst().drop(while: { $0 == " " || $0 == "\t" })
            blocks[index].text = AttributedString(blocks[index].text[label.startIndex ..< label.endIndex])
        }
        return blocks
    }

    private static func parse(
        _ source: String,
        syntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax,
        sourcePositions: Bool = false
    ) -> AttributedString {
        do {
            return try AttributedString(
                markdown: source,
                options: .init(
                    interpretedSyntax: syntax,
                    failurePolicy: .returnPartiallyParsedIfPossible,
                    appliesSourcePositionAttributes: sourcePositions
                )
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
        var showsMarker = false
        var checklistItem: MarkdownChecklist.Item?

        var components: [PresentationIntent.IntentType] {
            intent?.components ?? []
        }

        var headingLevel: Int? {
            for component in components {
                if case let .header(level) = component.kind {
                    return level
                }
            }
            return nil
        }

        var isCode: Bool {
            components.contains {
                if case .codeBlock = $0.kind {
                    return true
                }
                return false
            }
        }

        var quoteDepth: Int {
            components.filter { $0.kind == .blockQuote }.count
        }

        var isQuote: Bool {
            quoteDepth > 0
        }

        var isThematicBreak: Bool {
            components.contains { $0.kind == .thematicBreak }
        }

        var isInList: Bool {
            components.contains {
                if case .listItem = $0.kind {
                    true
                } else {
                    false
                }
            }
        }

        var listMarker: String? {
            guard showsMarker else { return nil }
            for component in components {
                if case let .listItem(ordinal) = component.kind {
                    let list = components.first { $0.kind == .orderedList || $0.kind == .unorderedList }
                    return list?.kind == .orderedList ? "\(ordinal)." : "•"
                }
            }
            return nil
        }

        var listDepth: Int {
            components.filter {
                $0.kind == .orderedList || $0.kind == .unorderedList
            }.count
        }
    }
}
