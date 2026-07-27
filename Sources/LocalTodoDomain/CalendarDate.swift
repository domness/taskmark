import Foundation

public struct CalendarDate: Codable, Comparable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        guard let utc = TimeZone(secondsFromGMT: 0) else {
            throw DomainValidationError.invalidCalendarDate
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let components = DateComponents(year: year, month: month, day: day)

        guard let date = calendar.date(from: components) else {
            throw DomainValidationError.invalidCalendarDate
        }

        let validated = calendar.dateComponents([.year, .month, .day], from: date)
        guard validated.year == year, validated.month == month, validated.day == day else {
            throw DomainValidationError.invalidCalendarDate
        }

        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ value: String) throws {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            parts[0].count == 4,
            parts[1].count == 2,
            parts[2].count == 2,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            throw DomainValidationError.invalidCalendarDate
        }

        try self.init(year: year, month: month, day: day)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return lhs.day < rhs.day
    }
}

extension CalendarDate: CustomStringConvertible {
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
