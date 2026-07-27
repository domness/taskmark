struct MarkdownSections {
    enum LineEnding: String {
        case lineFeed = "\n"
        case carriageReturnLineFeed = "\r\n"
    }

    let frontmatter: String
    let bodySeparator: String
    let body: String
    let lineEnding: LineEnding

    static func parse(_ source: String) throws -> Self {
        let lineEnding: LineEnding
        if source.hasPrefix("---\r\n") {
            lineEnding = .carriageReturnLineFeed
        } else if source.hasPrefix("---\n") {
            lineEnding = .lineFeed
        } else {
            throw MarkdownDocumentError.missingOpeningDelimiter
        }

        let frontmatterStart = source.index(source.startIndex, offsetBy: 3 + lineEnding.rawValue.count)
        var lineStart = frontmatterStart

        while lineStart < source.endIndex {
            let lineBreak = source[lineStart...].firstIndex(where: { $0 == "\n" || $0 == "\r\n" })
            let contentEnd = lineBreak ?? source.endIndex

            if source[lineStart ..< contentEnd] == "---" {
                return sections(
                    source: source,
                    frontmatterStart: frontmatterStart,
                    delimiterRange: lineStart ..< contentEnd,
                    lineBreak: lineBreak,
                    lineEnding: lineEnding
                )
            }

            guard let lineBreak else {
                break
            }
            lineStart = source.index(after: lineBreak)
        }

        throw MarkdownDocumentError.missingClosingDelimiter
    }

    private static func sections(
        source: String,
        frontmatterStart: String.Index,
        delimiterRange: Range<String.Index>,
        lineBreak: String.Index?,
        lineEnding: LineEnding
    ) -> Self {
        let bodyStart = lineBreak.map(source.index(after:)) ?? source.endIndex
        let bodySeparator = String(source[delimiterRange.upperBound ..< bodyStart])

        return Self(
            frontmatter: String(source[frontmatterStart ..< delimiterRange.lowerBound]),
            bodySeparator: bodySeparator,
            body: String(source[bodyStart...]),
            lineEnding: lineEnding
        )
    }
}
