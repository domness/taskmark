import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import Testing

@Test(arguments: [TaskStatus.inbox, .next, .waiting, .someday, .done, .canceled])
func overdueHighlightExcludesCompletedTasks(status: TaskStatus) throws {
    let task = try overdueTask(status: status, scheduled: "2026-09-17", deadline: "2026-09-16")
    let overdue = try TaskOverdueState(task: task, today: CalendarDate("2026-09-18"))
    #expect(overdue.scheduled == !status.isComplete)
    #expect(overdue.deadline == !status.isComplete)
    #expect(overdue.isOverdue == !status.isComplete)
}

@Test func overdueHighlightUsesStrictCalendarDayBoundaries() throws {
    let today = try CalendarDate("2026-09-18")
    for date in [nil, "2026-09-18", "2026-09-19"] as [String?] {
        let task = try overdueTask(scheduled: date, deadline: date)
        #expect(!TaskOverdueState(task: task, today: today).isOverdue)
    }
    let scheduled = try overdueTask(scheduled: "2026-09-17", deadline: "2026-09-20")
    #expect(TaskOverdueState(task: scheduled, today: today).scheduled)
    #expect(!TaskOverdueState(task: scheduled, today: today).deadline)
    let deadline = try overdueTask(scheduled: nil, deadline: "2026-09-17")
    #expect(TaskOverdueState(task: deadline, today: today).deadline)
    #expect(!TaskOverdueState(task: deadline, today: today).scheduled)
}

@Test func overdueHighlightRespectsVaultTimezoneAtMidnight() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-09-18T00:30:00Z"))
    let task = try overdueTask(scheduled: "2026-09-17", deadline: nil)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    #expect(try !TaskOverdueState(task: task, today: CalendarDate(date: now, calendar: calendar)).isOverdue)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
    #expect(try TaskOverdueState(task: task, today: CalendarDate(date: now, calendar: calendar)).isOverdue)
}

private func overdueTask(
    status: TaskStatus = .next, scheduled: String?, deadline: String?
) throws -> TodoTask {
    let now = Date(timeIntervalSince1970: 1_789_689_600)
    return try TodoTask(
        path: VaultPath("Tasks/overdue.md"), title: "Review", status: status,
        scheduled: scheduled.map(CalendarDate.init), deadline: deadline.map(CalendarDate.init),
        createdAt: now, updatedAt: now, completedAt: status == .done ? now : nil
    )
}
