import Foundation
import LocalTodoDomain
import Yams

struct FrontmatterReader {
    let document: MarkdownDocument

    func requiredString(_ key: FrontmatterKey) throws -> String {
        guard let value = try optionalString(key) else {
            throw EntityDocumentError.missingField(key.rawValue)
        }
        return value
    }

    func optionalString(_ key: FrontmatterKey) throws -> String? {
        guard let node = document.node(forKey: key.rawValue), node.null == nil else {
            return nil
        }
        guard let value = node.scalar?.string else {
            throw EntityDocumentError.invalidField(key.rawValue)
        }
        return value
    }

    func strings(_ key: FrontmatterKey) throws -> [String] {
        guard let node = document.node(forKey: key.rawValue) else {
            return []
        }
        guard case let .sequence(sequence) = node else {
            throw EntityDocumentError.invalidField(key.rawValue)
        }
        let values = sequence.compactMap { $0.scalar?.string }
        guard values.count == sequence.count else {
            throw EntityDocumentError.invalidField(key.rawValue)
        }
        return values
    }

    func date(_ key: FrontmatterKey) throws -> CalendarDate? {
        guard let value = try optionalString(key) else {
            return nil
        }
        do {
            return try CalendarDate(value)
        } catch {
            throw EntityDocumentError.invalidField(key.rawValue)
        }
    }

    func timestamp(_ key: FrontmatterKey, required: Bool) throws -> Date? {
        guard let value = try optionalString(key) else {
            if required {
                throw EntityDocumentError.missingField(key.rawValue)
            }
            return nil
        }
        guard value.hasSuffix("Z"), let date = ISO8601DateFormatter().date(from: value) else {
            throw EntityDocumentError.invalidField(key.rawValue)
        }
        return date
    }

    func requiredTimestamp(_ key: FrontmatterKey) throws -> Date {
        guard let value = try timestamp(key, required: true) else {
            throw EntityDocumentError.missingField(key.rawValue)
        }
        return value
    }

    func path(_ key: FrontmatterKey) throws -> VaultPath? {
        guard let value = try optionalString(key) else {
            return nil
        }
        do {
            return try VaultPath(value)
        } catch {
            throw EntityDocumentError.invalidField(key.rawValue)
        }
    }
}
