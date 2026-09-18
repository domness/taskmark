import Foundation
import Yams

enum ConfigurationDocument {
    static func preferences(_ changes: [String: ConfigurationValue], in data: Data) throws -> Data {
        var mapping = try mapping(data)
        let key = Node.scalar(.init("preferences"))
        let patch = try node(.object(changes))
        mapping[key] = merge(mapping[key], with: patch)
        return try render(mapping)
    }

    static func timezone(_ timezone: String?, in data: Data) throws -> Data {
        var mapping = try mapping(data)
        mapping[.scalar(.init("timezone"))] = timezone.map { .scalar(.init($0)) }
        return try render(mapping)
    }

    private static func mapping(_ data: Data) throws -> Node.Mapping {
        guard let source = String(data: data, encoding: .utf8),
              let mapping = try Yams.compose(yaml: source)?.mapping
        else {
            throw VaultStoreError.invalidVault("The configuration must be a UTF-8 YAML mapping")
        }
        return mapping
    }

    private static func node(_ value: ConfigurationValue) throws -> Node {
        guard let node = try Yams.compose(yaml: YAMLEncoder().encode(value)) else {
            throw VaultStoreError.invalidVault("Cannot encode configuration preferences")
        }
        return node
    }

    private static func merge(_ original: Node?, with patch: Node) -> Node {
        guard var original = original?.mapping, let changes = patch.mapping else { return patch }
        for (key, value) in changes {
            original[key] = merge(original[key], with: value)
        }
        return .mapping(original)
    }

    private static func render(_ mapping: Node.Mapping) throws -> Data {
        try Data(Yams.serialize(node: .mapping(mapping)).utf8)
    }
}
