import Foundation
import LocalTodoDomain
import Testing

@Test func completingTaskSetsStatusAndTimestamp() throws {
    let task = try makeTask()
    let completion = testNow.addingTimeInterval(60)

    let completed = try TaskTransition.complete(
        task,
        now: completion,
        today: CalendarDate("2026-07-27"),
        calendar: testCalendar()
    )

    #expect(completed.status == .done)
    #expect(completed.completedAt == completion)
    #expect(completed.updatedAt == completion)
}

@Test func reopeningTaskClearsCompletionTimestamp() throws {
    let task = try makeTask(status: .done)
    let reopened = try TaskTransition.reopen(task, status: .next, now: testNow.addingTimeInterval(60))

    #expect(reopened.status == .next)
    #expect(reopened.completedAt == nil)
}

@Test func completingRecurringTaskRollsItForward() throws {
    let rule = try FixedRecurrenceRule(frequency: .weekly, weekdays: [.monday])
    let task = try makeTask(
        scheduled: CalendarDate("2026-07-27"),
        recurrence: .fixed(rule)
    )

    let next = try TaskTransition.complete(
        task,
        now: testNow.addingTimeInterval(60),
        today: CalendarDate("2026-07-27"),
        calendar: testCalendar()
    )
    let expected = try CalendarDate("2026-08-03")

    #expect(next.status == .next)
    #expect(next.scheduled == expected)
    #expect(next.completedAt == nil)
}

@Test(arguments: [
    ("2026-07-01" as String?, nil as String?, "2026-07-27", "2026-07-30" as String?, nil as String?),
    ("2026-08-10", nil, "2026-07-27", "2026-07-30", nil),
    (nil, "2026-07-01", "2026-07-27", nil, "2026-07-30"),
    (nil, "2026-08-10", "2026-07-27", nil, "2026-07-30"),
    (nil, nil, "2026-07-27", "2026-07-30", nil),
    ("2026-07-01", "2026-07-06", "2026-07-27", "2026-07-30", "2026-08-04"),
    ("2026-08-10", "2026-08-15", "2026-07-27", "2026-07-30", "2026-08-04"),
    ("2026-08-10", "2026-08-05", "2026-07-27", "2026-07-30", "2026-07-25"),
    ("2026-07-01", "2026-07-01", "2026-07-27", "2026-07-30", "2026-07-30"),
])
func completingAfterCompletionRecurrenceUsesToday(
    scheduled: String?, deadline: String?, today: String,
    expectedScheduled: String?, expectedDeadline: String?
) throws {
    let body = "Notes\r\n- [x] Finished\r\n- [X] Also finished\r\n- [ ] Pending\r\n"
    let task = try makeTask(
        scheduled: scheduled.map(CalendarDate.init),
        deadline: deadline.map(CalendarDate.init),
        recurrence: .afterCompletion(RecurrenceInterval(value: 3, unit: .day)),
        body: body
    )
    let next = try TaskTransition.complete(
        task, now: testNow, today: CalendarDate(today), calendar: testCalendar()
    )

    #expect(try next.scheduled == (expectedScheduled.map(CalendarDate.init)))
    #expect(try next.deadline == (expectedDeadline.map(CalendarDate.init)))
    #expect(next.status == .next)
    #expect(next.completedAt == nil)
    #expect(next.updatedAt == testNow)
    #expect(next.path == task.path)
    #expect(next.recurrence == task.recurrence)
    #expect(Array(next.body.utf8) == Array(body.utf8))
}

@Test(arguments: ["2026-06-01", "2026-09-01"])
func completingFixedRecurrenceAdvancesOneStepFromPreviousDate(today: String) throws {
    let task = try makeTask(
        scheduled: CalendarDate("2026-07-27"),
        deadline: CalendarDate("2026-08-01"),
        recurrence: .fixed(FixedRecurrenceRule(frequency: .weekly, weekdays: [.monday])),
        body: "- [x] Keep checked\n"
    )
    let next = try TaskTransition.complete(
        task, now: testNow, today: CalendarDate(today), calendar: testCalendar()
    )

    #expect(try next.scheduled == CalendarDate("2026-08-03"))
    #expect(try next.deadline == CalendarDate("2026-08-08"))
    #expect(next.body == task.body)
}

@Test(arguments: [
    DSTRecurrenceCase(
        timezone: "America/New_York",
        scheduled: "2026-03-07",
        deadline: "2026-03-10",
        today: "2026-03-08",
        expectedScheduled: "2026-03-09",
        expectedDeadline: "2026-03-12"
    ),
    DSTRecurrenceCase(
        timezone: "America/New_York",
        scheduled: "2026-10-31",
        deadline: "2026-11-03",
        today: "2026-11-01",
        expectedScheduled: "2026-11-02",
        expectedDeadline: "2026-11-05"
    ),
    DSTRecurrenceCase(
        timezone: "Europe/London",
        scheduled: "2026-03-28",
        deadline: "2026-03-31",
        today: "2026-03-29",
        expectedScheduled: "2026-03-30",
        expectedDeadline: "2026-04-02"
    ),
    DSTRecurrenceCase(
        timezone: "Pacific/Auckland",
        scheduled: "2026-09-26",
        deadline: "2026-09-29",
        today: "2026-09-27",
        expectedScheduled: "2026-09-28",
        expectedDeadline: "2026-10-01"
    ),
])
func completingRecurrencePreservesCalendarDaysAcrossDST(
    values: DSTRecurrenceCase
) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: values.timezone))
    let task = try makeTask(
        scheduled: CalendarDate(values.scheduled),
        deadline: CalendarDate(values.deadline),
        recurrence: .afterCompletion(RecurrenceInterval(value: 1, unit: .day))
    )
    let next = try TaskTransition.complete(
        task, now: testNow, today: CalendarDate(values.today), calendar: calendar
    )

    #expect(try next.scheduled == CalendarDate(values.expectedScheduled))
    #expect(try next.deadline == CalendarDate(values.expectedDeadline))
}

struct DSTRecurrenceCase: Sendable {
    let timezone: String
    let scheduled: String
    let deadline: String
    let today: String
    let expectedScheduled: String
    let expectedDeadline: String
}
