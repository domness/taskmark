import Foundation

public struct FixedRecurrenceRule: Equatable, Sendable {
    public enum Frequency: String, Codable, CaseIterable, Sendable {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }

    public let frequency: Frequency
    public let interval: Int
    public let weekdays: [Weekday]

    public init(frequency: Frequency, interval: Int = 1, weekdays: [Weekday] = []) throws {
        guard (1 ... 999).contains(interval) else {
            throw DomainValidationError.invalidRecurrenceRule
        }
        guard frequency == .weekly || weekdays.isEmpty else {
            throw DomainValidationError.invalidRecurrenceRule
        }
        guard Set(weekdays).count == weekdays.count else {
            throw DomainValidationError.invalidRecurrenceRule
        }

        self.frequency = frequency
        self.interval = interval
        self.weekdays = weekdays
    }

    public func next(after date: CalendarDate, calendar: Calendar) throws -> CalendarDate {
        switch frequency {
        case .daily:
            try date.adding(DateComponents(day: interval), calendar: calendar)
        case .weekly:
            try nextWeekly(after: date, calendar: calendar)
        case .monthly:
            try date.adding(DateComponents(month: interval), calendar: calendar)
        case .yearly:
            try date.adding(DateComponents(year: interval), calendar: calendar)
        }
    }

    private func nextWeekly(after date: CalendarDate, calendar: Calendar) throws -> CalendarDate {
        let anchorDate = try date.date(in: calendar)
        let anchorWeekday = try Weekday(calendarValue: calendar.component(.weekday, from: anchorDate))
        let acceptedWeekdays = Set(weekdays.isEmpty ? [anchorWeekday] : weekdays)
        guard let anchorWeek = calendar.dateInterval(of: .weekOfYear, for: anchorDate)?.start else {
            throw DomainValidationError.invalidRecurrenceRule
        }

        for offset in 1 ... (interval * 14 + 7) {
            let candidate = try date.adding(DateComponents(day: offset), calendar: calendar)
            let candidateDate = try candidate.date(in: calendar)
            let weekday = try Weekday(calendarValue: calendar.component(.weekday, from: candidateDate))
            guard acceptedWeekdays.contains(weekday) else {
                continue
            }
            guard let candidateWeek = calendar.dateInterval(of: .weekOfYear, for: candidateDate)?.start else {
                continue
            }
            let dayDifference = calendar.dateComponents([.day], from: anchorWeek, to: candidateWeek).day ?? 0
            if dayDifference / 7 % interval == 0 {
                return candidate
            }
        }

        throw DomainValidationError.invalidRecurrenceRule
    }
}
