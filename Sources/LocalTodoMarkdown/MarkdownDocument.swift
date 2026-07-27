import Yams

public struct MarkdownDocument {
    private var frontmatter: Node
    private let bodySeparator: String
    private let lineEnding: MarkdownSections.LineEnding

    public let body: String

    public static func parse(_ source: String) throws -> Self {
        let sections = try MarkdownSections.parse(source)
        let frontmatter: Node

        do {
            guard let node = try compose(yaml: sections.frontmatter) else {
                throw MarkdownDocumentError.frontmatterMustBeMapping
            }
            frontmatter = node
        } catch let error as MarkdownDocumentError {
            throw error
        } catch {
            throw MarkdownDocumentError.malformedFrontmatter
        }

        guard case .mapping = frontmatter else {
            throw MarkdownDocumentError.frontmatterMustBeMapping
        }

        return Self(
            frontmatter: frontmatter,
            bodySeparator: sections.bodySeparator,
            lineEnding: sections.lineEnding,
            body: sections.body
        )
    }

    public func string(forKey key: String) -> String? {
        frontmatter[key]?.string
    }

    public func strings(forKey key: String) -> [String]? {
        guard let value = frontmatter[key], case .sequence = value else {
            return nil
        }
        return value.array(of: String.self)
    }

    public mutating func set(_ update: FrontmatterUpdate, for key: FrontmatterKey) {
        guard case var .mapping(mapping) = frontmatter else {
            return
        }

        mapping[key.rawValue] = node(for: update)
        frontmatter = .mapping(mapping)
    }

    public func rendered() throws -> String {
        let emitted = try serialize(
            node: frontmatter,
            indent: 2,
            width: -1,
            allowUnicode: true,
            lineBreak: emitterLineBreak
        )
        let yaml = emitted.hasSuffix(lineEnding.rawValue) ? emitted : emitted + lineEnding.rawValue

        return "---\(lineEnding.rawValue)\(yaml)---\(bodySeparator)\(body)"
    }

    private func node(for update: FrontmatterUpdate) -> Node? {
        switch update {
        case let .string(value):
            Node(value, Tag(.str))
        case let .strings(values):
            Node(values.map { Node($0, Tag(.str)) })
        case .null:
            Node("null", Tag(.null))
        case .remove:
            nil
        }
    }

    private var emitterLineBreak: Emitter.LineBreak {
        switch lineEnding {
        case .lineFeed: .ln
        case .carriageReturnLineFeed: .crln
        }
    }
}
