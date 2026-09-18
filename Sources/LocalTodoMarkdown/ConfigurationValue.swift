import Foundation

/// Portable YAML preference values; clients can project known fields without dropping future keys.
public enum ConfigurationValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([Self])
    case object([String: Self])

    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let bool = try? value.decode(Bool.self) {
            self = .bool(bool)
        } else if let integer = try? value.decode(Int.self) {
            self = .integer(integer)
        } else if let number = try? value.decode(Double.self) {
            self = .number(number)
        } else if let string = try? value.decode(String.self) {
            self = .string(string)
        } else if let array = try? value.decode([Self].self) {
            self = .array(array)
        } else {
            self = try .object(value.decode([String: Self].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case let .bool(item): try value.encode(item)
        case let .integer(item): try value.encode(item)
        case let .number(item): try value.encode(item)
        case let .string(item): try value.encode(item)
        case let .array(item): try value.encode(item)
        case let .object(item): try value.encode(item)
        }
    }

    public static func encode(_ value: some Encodable) throws -> Self {
        try JSONDecoder().decode(Self.self, from: JSONEncoder().encode(value))
    }

    public func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(self))
    }

    public func merging(_ update: Self) -> Self {
        guard case var .object(existing) = self, case let .object(changes) = update else { return update }
        for (key, value) in changes {
            existing[key] = existing[key]?.merging(value) ?? value
        }
        return .object(existing)
    }

    /// Send only changed leaves so untouched extension metadata keeps its original YAML representation.
    public func changes(comparedTo original: Self?) -> Self {
        guard case let .object(base) = original, case let .object(updated) = self else { return self }
        var patch = [String: Self]()
        for (key, value) in updated where value != base[key] {
            patch[key] = value.changes(comparedTo: base[key])
        }
        return .object(patch)
    }

    public func rebasingChanges(from original: Self?, onto remote: Self?) -> Self {
        guard case let .object(local) = self else { return self }
        let base: [String: Self] = if case let .object(value) = original {
            value
        } else {
            [:]
        }
        var merged: [String: Self] = if case let .object(value) = remote {
            value
        } else {
            [:]
        }
        for (key, value) in local where value != base[key] {
            merged[key] = merged[key].map { value.rebasingChanges(from: base[key], onto: $0) } ?? value
        }
        return .object(merged)
    }
}
