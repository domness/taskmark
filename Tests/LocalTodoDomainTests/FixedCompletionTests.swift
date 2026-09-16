import LocalTodoDomain
import Testing

@Test(arguments: [
    (FixedRecurrenceRule.Frequency.daily, 3, "2026-07-01", "2026-07-27", "2026-07-28"),
    (.weekly, 2, "2026-07-01", "2026-07-29", "2026-08-12"),
    (.monthly, 1, "2026-01-31", "2026-03-01", "2026-03-28"),
    (.yearly, 1, "2024-02-29", "2026-03-01", "2027-02-28"),
])
func fixedCompletionFollowsCadence(
    frequency: FixedRecurrenceRule.Frequency, interval: Int, anchor: String, today: String, expected: String
) throws {
    let task = try makeTask(
        deadline: CalendarDate(anchor),
        recurrence: .fixed(FixedRecurrenceRule(frequency: frequency, interval: interval))
    )
    let next = try TaskTransition.complete(task, now: testNow, today: CalendarDate(today), calendar: testCalendar())
    #expect(next.scheduled == nil)
    #expect(try next.deadline == CalendarDate(expected))
}

@Test func fixedCompletionSkipsSelectedWeekdaysAndKeepsNegativeOffset() throws {
    let task = try makeTask(
        scheduled: CalendarDate("2026-07-27"), deadline: CalendarDate("2026-07-25"),
        recurrence: .fixed(FixedRecurrenceRule(frequency: .weekly, interval: 2, weekdays: [.monday, .wednesday]))
    )
    let next = try TaskTransition.complete(
        task, now: testNow, today: CalendarDate("2026-08-10"), calendar: testCalendar()
    )
    #expect(try next.scheduled == CalendarDate("2026-08-12"))
    #expect(try next.deadline == CalendarDate("2026-08-10"))
}

@Test func undatedFixedCompletionStartsFromCompletionDay() throws {
    let task = try makeTask(recurrence: .fixed(FixedRecurrenceRule(frequency: .daily)))
    let next = try TaskTransition.complete(
        task, now: testNow, today: CalendarDate("2026-07-27"), calendar: testCalendar()
    )
    #expect(try next.scheduled == CalendarDate("2026-07-28"))
    #expect(next.deadline == nil)
}
