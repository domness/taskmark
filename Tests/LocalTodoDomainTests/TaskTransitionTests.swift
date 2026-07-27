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
