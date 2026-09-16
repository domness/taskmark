import Foundation
import Yams

enum FrontmatterNodes {
    static func boolean(_ value: Bool) -> Node {
        Node(value ? "true" : "false", Tag(.bool))
    }

    static func string(_ value: String) -> Node {
        Node(value, Tag(.str))
    }

    static func optionalString(_ value: String?) -> Node? {
        value.map(string)
    }

    static func strings(_ values: [String]) -> Node {
        Node(values.map(string))
    }

    static func date(_ value: Date) -> Node {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return string(formatter.string(from: value))
    }

    static func optionalDate(_ value: Date?) -> Node {
        value.map(date) ?? Node("null", Tag(.null))
    }
}
