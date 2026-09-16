import LocalTodoDomain
import Yams

enum SavedFilterDocumentCodec {
    static func decode(_ document: MarkdownDocument) throws -> [SavedTaskFilter] {
        guard document.string(forKey: "schema") == "1",
              case let .sequence(nodes) = document.node(forKey: "filters")
        else {
            throw SavedFilterError.invalidFormat("Expected schema: 1 and a filters list.")
        }
        do {
            let filters = try nodes.map {
                try YAMLDecoder().decode(SavedFilterFields.self, from: serialize(node: $0)).filter()
            }
            try validate(filters)
            return filters
        } catch let error as SavedFilterError {
            throw error
        } catch {
            throw SavedFilterError.invalidFormat("Check filter names, field types, dates and query values.")
        }
    }

    static func encode(
        _ filters: [SavedTaskFilter],
        preserving existing: MarkdownDocument?
    ) throws -> MarkdownDocument {
        try validate(filters)
        var document = existing ?? .create(fields: [("schema", Node("1", Tag(.int)))], body: "")
        var previous = [String: Node]()
        if let existing {
            _ = try decode(existing)
            if case let .sequence(nodes) = existing.node(forKey: "filters") {
                for node in nodes {
                    if let name = node["name"]?.scalar?.string {
                        previous[name] = node
                    }
                }
            }
        }
        let nodes = try filters.map { filter in
            var node = previous[filter.name] ?? .mapping([:])
            guard let fields = try compose(yaml: YAMLEncoder().encode(SavedFilterFields(filter))) else {
                throw SavedFilterError.invalidFormat("Unable to encode filter.")
            }
            for key in SavedFilterFields.CodingKeys.allCases {
                node[key.rawValue] = fields[key.rawValue]
            }
            return node
        }
        document.setNode(Node(nodes), forKey: "filters")
        return document
    }

    private static func validate(_ filters: [SavedTaskFilter]) throws {
        guard Set(filters.map(\.name)).count == filters.count else {
            throw SavedFilterError.invalidFormat("Filter names must be unique and case-sensitive.")
        }
    }
}
