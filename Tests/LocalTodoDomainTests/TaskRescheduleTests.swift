import Foundation
import LocalTodoDomain
import Testing

@Test(arguments: [
    ("2026-03-07" as String?, "2026-03-10" as String?, "2026-03-09", "2026-03-09" as String?, "2026-03-12" as String?),
    ("2026-03-10", "2026-03-07", "2026-11-01", "2026-11-01", "2026-10-29"),
    (nil, "2026-03-10", "2026-03-09", nil, "2026-03-09"),
    ("2026-03-10", nil, "2026-03-09", "2026-03-09", nil),
    (nil, nil, "2026-03-09", "2026-03-09", nil),
])
func reschedulingPreservesSignedCalendarOffsets(
    scheduled: String?, deadline: String?, target: String, expectedScheduled: String?, expectedDeadline: String?
) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    let task = try makeTask(
        scheduled: scheduled.map(CalendarDate.init),
        deadline: deadline.map(CalendarDate.init),
        recurrence: .afterCompletion(RecurrenceInterval(value: 3, unit: .day)),
        body: "- [X] Keep\r\n"
    )
    let updated = try TaskTransition.reschedule(task, to: CalendarDate(target), now: testNow, calendar: calendar)
    #expect(try updated.scheduled == expectedScheduled.map(CalendarDate.init))
    #expect(try updated.deadline == expectedDeadline.map(CalendarDate.init))
    #expect(updated.recurrence == task.recurrence)
    #expect(updated.body == task.body)
    #expect(updated.status == task.status)
    #expect(updated.path == task.path)
}

@Test func reschedulingDoesNotChangeAnAlreadyMatchingDate() throws {
    let task = try makeTask(scheduled: CalendarDate("2026-09-16"))
    #expect(try TaskTransition.reschedule(
        task,
        to: CalendarDate("2026-09-16"),
        now: testNow.addingTimeInterval(60),
        calendar: testCalendar()
    ) == task)
}

@Test(arguments: [TaskStatus.done, .canceled])
func reschedulingRequiresAnIncompleteTask(status: TaskStatus) throws {
    let task = try makeTask(status: status)
    #expect(throws: DomainValidationError.invalidCompletionState) {
        try TaskTransition.reschedule(task, to: CalendarDate("2026-09-16"), now: testNow, calendar: testCalendar())
    }
}
