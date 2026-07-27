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

    public init(date: Date, calendar: Calendar) throws {
        let gregorian = Self.gregorianCalendar(timeZone: calendar.timeZone)
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
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

    public func date(in calendar: Calendar) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let date = Self.gregorianCalendar(timeZone: calendar.timeZone).date(from: components) else {
            throw DomainValidationError.invalidCalendarDate
        }
        return date
    }

    public func adding(_ components: DateComponents, calendar: Calendar) throws -> Self {
        let gregorian = Self.gregorianCalendar(timeZone: calendar.timeZone)
        let date = try date(in: gregorian)
        guard let result = gregorian.date(byAdding: components, to: date) else {
            throw DomainValidationError.invalidCalendarDate
        }
        let resultComponents = gregorian.dateComponents([.year, .month, .day], from: result)
        guard
            let year = resultComponents.year,
            let month = resultComponents.month,
            let day = resultComponents.day
        else {
            throw DomainValidationError.invalidCalendarDate
        }
        return try Self(year: year, month: month, day: day)
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

extension CalendarDate: CustomStringConvertible {
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
