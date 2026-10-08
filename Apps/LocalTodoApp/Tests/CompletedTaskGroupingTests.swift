import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import Testing

struct CompletedTaskGroupingTests {
    @Test func groupsDoneTasksByVaultDayNewestFirst() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let formatter = ISO8601DateFormatter()
        let tasks = try [
            completedTask("Earlier", at: #require(formatter.date(from: "2026-10-08T08:00:00Z"))),
            completedTask("Latest", at: #require(formatter.date(from: "2026-10-09T01:00:00Z"))),
            completedTask("Previous day", at: #require(formatter.date(from: "2026-10-08T06:00:00Z"))),
        ]

        let groups = CompletedTaskGrouping.groups(tasks, calendar: calendar)

        #expect(groups.map(\.date.description) == ["2026-10-08", "2026-10-07"])
        #expect(groups[0].tasks.map(\.title) == ["Latest", "Earlier"])
        #expect(groups[1].tasks.map(\.title) == ["Previous day"])
    }

    private func completedTask(_ title: String, at date: Date) throws -> TodoTask {
        try TodoTask(
            path: VaultPath("Tasks/\(title).md"),
            title: title,
            status: .done,
            createdAt: .distantPast,
            updatedAt: date,
            completedAt: date
        )
    }
}
