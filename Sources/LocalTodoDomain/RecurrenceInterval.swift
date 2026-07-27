import Foundation

public struct RecurrenceInterval: Equatable, Sendable {
    public enum Unit: String, Codable, CaseIterable, Sendable {
        case day = "D"
        case week = "W"
        case month = "M"
        case year = "Y"
    }

    public let value: Int
    public let unit: Unit

    public init(value: Int, unit: Unit) throws {
        guard (1 ... 999).contains(value) else {
            throw DomainValidationError.invalidRecurrenceRule
        }
        self.value = value
        self.unit = unit
    }

    public func dateComponents() -> DateComponents {
        switch unit {
        case .day: DateComponents(day: value)
        case .week: DateComponents(day: value * 7)
        case .month: DateComponents(month: value)
        case .year: DateComponents(year: value)
        }
    }
}
