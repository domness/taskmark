public enum MarkdownDocumentError: Error, Equatable, Sendable {
    case missingOpeningDelimiter
    case missingClosingDelimiter
    case malformedFrontmatter
    case frontmatterMustBeMapping
}
