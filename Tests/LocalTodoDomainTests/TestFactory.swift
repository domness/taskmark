import Foundation
import LocalTodoDomain

let testNow = Date(timeIntervalSince1970: 1_774_608_000)

func testCalendar() throws -> Calendar {
    guard let timezone = TimeZone(identifier: "Europe/London") else {
        throw TestFactoryError.missingTimezone
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timezone
    calendar.firstWeekday = 2
    return calendar
}

func makeTask(
    path: String = "Tasks/Test.md",
    title: String = "Test task",
    status: TaskStatus = .next,
    priority: TaskPriority? = nil,
    scheduled: CalendarDate? = nil,
    deadline: CalendarDate? = nil,
    project: VaultPath? = nil,
    area: VaultPath? = nil,
    tags: [String] = [],
    recurrence: TaskRecurrence? = nil,
    body: String = ""
) throws -> TodoTask {
    try TodoTask(
        path: VaultPath(path),
        title: title,
        status: status,
        priority: priority,
        scheduled: scheduled,
        deadline: deadline,
        project: project,
        area: area,
        tags: tags,
        recurrence: recurrence,
        body: body,
        createdAt: testNow,
        updatedAt: testNow,
        completedAt: status == .done ? testNow : nil
    )
}

private enum TestFactoryError: Error {
    case missingTimezone
}
