import LocalTodoDomain
import Yams

enum RecurrenceDocumentCodec {
    static func decode(_ node: Node?) throws -> TaskRecurrence? {
        guard let node, node.null == nil else {
            return nil
        }
        guard case let .mapping(mapping) = node, let mode = mapping["mode"]?.scalar?.string else {
            throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
        }

        switch mode {
        case "fixed":
            guard let value = mapping["rule"]?.scalar?.string else {
                throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
            }
            return try .fixed(parseFixed(value))
        case "after-completion":
            guard let value = mapping["interval"]?.scalar?.string else {
                throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
            }
            return try .afterCompletion(parseInterval(value))
        default:
            throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
        }
    }

    static func encode(_ recurrence: TaskRecurrence?, preserving existing: Node? = nil) -> Node? {
        guard let recurrence else {
            return nil
        }
        var node: Node.Mapping = existing?.mapping ?? [:]
        switch recurrence {
        case let .fixed(rule):
            node["mode"] = FrontmatterNodes.string("fixed")
            node["rule"] = FrontmatterNodes.string(format(rule))
            node["interval"] = nil
        case let .afterCompletion(interval):
            node["mode"] = FrontmatterNodes.string("after-completion")
            node["interval"] = FrontmatterNodes.string("P\(interval.value)\(interval.unit.rawValue)")
            node["rule"] = nil
        }
        return .mapping(node)
    }

    static func parseFixed(_ value: String) throws -> FixedRecurrenceRule {
        var fields = [String: String]()
        for component in value.split(separator: ";") {
            let pair = component.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, fields.updateValue(String(pair[1]), forKey: String(pair[0])) == nil else {
                throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
            }
        }
        guard
            fields.keys.allSatisfy({ ["FREQ", "INTERVAL", "BYDAY"].contains($0) }),
            let frequencyValue = fields["FREQ"],
            let frequency = FixedRecurrenceRule.Frequency(rawValue: frequencyValue)
        else {
            throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
        }

        let interval = try parsePositiveInteger(fields["INTERVAL"] ?? "1")
        let weekdays: [Weekday] = if let weekdayValues = fields["BYDAY"]?.split(separator: ",") {
            try weekdayValues.map {
                guard let weekday = Weekday(rawValue: String($0)) else {
                    throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
                }
                return weekday
            }
        } else {
            []
        }

        do {
            return try FixedRecurrenceRule(frequency: frequency, interval: interval, weekdays: weekdays)
        } catch let error as DomainValidationError {
            throw EntityDocumentError.invalidDomainValue(error)
        }
    }

    static func parseInterval(_ value: String) throws -> RecurrenceInterval {
        guard value.hasPrefix("P"), value.count >= 3, let unitValue = value.last else {
            throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
        }
        let numberStart = value.index(after: value.startIndex)
        let numberEnd = value.index(before: value.endIndex)
        let amount = try parsePositiveInteger(String(value[numberStart ..< numberEnd]))
        guard let unit = RecurrenceInterval.Unit(rawValue: String(unitValue)) else {
            throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
        }
        do {
            return try RecurrenceInterval(value: amount, unit: unit)
        } catch let error as DomainValidationError {
            throw EntityDocumentError.invalidDomainValue(error)
        }
    }

    private static func parsePositiveInteger(_ value: String) throws -> Int {
        guard let integer = Int(value), integer > 0 else {
            throw EntityDocumentError.invalidField(FrontmatterKey.recurrence.rawValue)
        }
        return integer
    }

    static func format(_ rule: FixedRecurrenceRule) -> String {
        var parts = ["FREQ=\(rule.frequency.rawValue)"]
        if rule.interval != 1 {
            parts.append("INTERVAL=\(rule.interval)")
        }
        if !rule.weekdays.isEmpty {
            parts.append("BYDAY=\(rule.weekdays.map(\.rawValue).joined(separator: ","))")
        }
        return parts.joined(separator: ";")
    }
}
