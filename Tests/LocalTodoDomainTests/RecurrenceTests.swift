import LocalTodoDomain
import Testing

@Test func fixedDailyRecurrenceAdvancesByInterval() throws {
    let rule = try FixedRecurrenceRule(frequency: .daily, interval: 3)

    let next = try rule.next(after: CalendarDate("2026-07-27"), calendar: testCalendar())
    let expected = try CalendarDate("2026-07-30")

    #expect(next == expected)
}

@Test func fixedWeeklyRecurrenceUsesSelectedWeekdays() throws {
    let rule = try FixedRecurrenceRule(frequency: .weekly, weekdays: [.monday, .wednesday, .friday])

    let next = try rule.next(after: CalendarDate("2026-07-27"), calendar: testCalendar())
    let expected = try CalendarDate("2026-07-29")

    #expect(next == expected)
}

@Test func fixedWeeklyRecurrenceHonorsInterval() throws {
    let rule = try FixedRecurrenceRule(frequency: .weekly, interval: 2, weekdays: [.monday])

    let next = try rule.next(after: CalendarDate("2026-07-27"), calendar: testCalendar())
    let expected = try CalendarDate("2026-08-10")

    #expect(next == expected)
}

@Test func afterCompletionRecurrenceUsesCalendarInterval() throws {
    let interval = try RecurrenceInterval(value: 1, unit: .month)
    let recurrence = TaskRecurrence.afterCompletion(interval)

    let next = try recurrence.next(after: CalendarDate("2026-07-27"), calendar: testCalendar())
    let expected = try CalendarDate("2026-08-27")

    #expect(next == expected)
}

@Test func recurrenceRejectsInvalidRules() {
    #expect(throws: DomainValidationError.invalidRecurrenceRule) {
        try FixedRecurrenceRule(frequency: .daily, interval: 0)
    }
    #expect(throws: DomainValidationError.invalidRecurrenceRule) {
        try FixedRecurrenceRule(frequency: .monthly, weekdays: [.monday])
    }
}
