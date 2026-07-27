import Foundation
import LocalTodoDomain
import Testing

@Test func calendarDateParsesCanonicalValue() throws {
    let date = try CalendarDate("2026-07-27")

    #expect(date.description == "2026-07-27")
}

@Test func calendarDateRejectsImpossibleValue() {
    #expect(throws: DomainValidationError.invalidCalendarDate) {
        try CalendarDate("2026-02-30")
    }
}

@Test func calendarDateUsesTheSuppliedCalendarTimezone() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let instant = try #require(ISO8601DateFormatter().date(from: "2026-07-28T02:00:00Z"))

    let date = try CalendarDate(date: instant, calendar: calendar)

    #expect(date.description == "2026-07-27")
}

@Test func calendarDateUsesGregorianFieldsFromANonGregorianCalendar() throws {
    var calendar = Calendar(identifier: .buddhist)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let instant = try #require(ISO8601DateFormatter().date(from: "2026-07-28T02:00:00Z"))

    let date = try CalendarDate(date: instant, calendar: calendar)

    #expect(date.description == "2026-07-27")
}

@Test func calendarDateRoundTripsAndAddsUsingGregorianFields() throws {
    var calendar = Calendar(identifier: .buddhist)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let original = try CalendarDate("2026-07-27")

    let instant = try original.date(in: calendar)
    let roundTrip = try CalendarDate(date: instant, calendar: calendar)
    let nextDay = try original.adding(DateComponents(day: 1), calendar: calendar)

    #expect(roundTrip == original)
    #expect(nextDay.description == "2026-07-28")
}
