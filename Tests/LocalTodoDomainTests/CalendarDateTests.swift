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
