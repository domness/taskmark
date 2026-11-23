import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import Testing

struct PlanningTaskGroupingTests {
    @Test func nextShowsEarliestPlanningDateAndKeepsUndatedTasksLast() throws {
        let tasks = try [
            task("Undated"),
            task("Second", scheduled: "2026-11-25"),
            task("First despite later schedule", scheduled: "2026-11-28", deadline: "2026-11-24"),
            task("Same date", deadline: "2026-11-25"),
        ]
        let groups = try PlanningTaskGrouping.groups(tasks, route: .next, today: CalendarDate("2026-11-23"))
        #expect(groups.map { $0.date?.description } == ["2026-11-24", "2026-11-25", nil])
        #expect(groups.map { $0.tasks.map(\.title) } == [
            ["First despite later schedule"], ["Second", "Same date"], ["Undated"],
        ])
    }

    @Test func upcomingUsesOnlyFutureDatesAndDoesNotDuplicateTasks() throws {
        let tasks = try [
            task("Future deadline", scheduled: "2026-11-23", deadline: "2026-11-26"),
            task("Future schedule", scheduled: "2026-11-24", deadline: "2026-11-22"),
            task("Both future", scheduled: "2026-11-27", deadline: "2026-11-24"),
        ]
        let groups = try PlanningTaskGrouping.groups(tasks, route: .upcoming, today: CalendarDate("2026-11-23"))
        #expect(groups.map { $0.date?.description } == ["2026-11-24", "2026-11-26"])
        #expect(groups.map { $0.tasks.map(\.title) } == [
            ["Future schedule", "Both future"], ["Future deadline"],
        ])
    }

    private func task(_ title: String, scheduled: String? = nil, deadline: String? = nil) throws -> TodoTask {
        try TodoTask(
            path: VaultPath("Tasks/\(title).md"),
            title: title,
            status: .next,
            scheduled: scheduled.map(CalendarDate.init),
            deadline: deadline.map(CalendarDate.init),
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
    }
}
