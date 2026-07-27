import LocalTodoDomain
import Testing

@Test func todayIncludesOverdueScheduledAndDeadlineTasks() throws {
    let today = try CalendarDate("2026-07-27")
    let tasks = try [
        makeTask(path: "Tasks/Scheduled.md", scheduled: CalendarDate("2026-07-26")),
        makeTask(path: "Tasks/Deadline.md", deadline: CalendarDate("2026-07-27")),
        makeTask(path: "Tasks/Future.md", scheduled: CalendarDate("2026-07-28")),
        makeTask(path: "Tasks/Done.md", status: .done, deadline: CalendarDate("2026-07-20")),
    ]

    let results = TaskQuery(scope: .today).results(from: tasks, today: today)

    #expect(results.map(\.path.value) == ["Tasks/Deadline.md", "Tasks/Scheduled.md"])
}

@Test func queryCombinesMetadataFilters() throws {
    let project = try VaultPath("Projects/App.md")
    let area = try VaultPath("Areas/Work.md")
    let matching = try makeTask(
        path: "Tasks/Matching.md",
        priority: .p1,
        scheduled: CalendarDate("2026-07-27"),
        project: project,
        area: area,
        tags: ["swift", "storage"]
    )
    let other = try makeTask(path: "Tasks/Other.md", priority: .p2, tags: ["swift"])
    var filters = TaskFilters()
    filters.priorities = [.p1]
    filters.project = project
    filters.area = area
    filters.tags = ["swift", "storage"]
    let today = try CalendarDate("2026-07-27")
    filters.scheduled = DateRange(start: today, end: today)

    let query = TaskQuery(scope: .all, filters: filters)
    let results = query.results(from: [other, matching], today: today)

    #expect(results.map(\.path.value) == ["Tasks/Matching.md"])
}

@Test func queryTextIsCaseAndDiacriticInsensitive() throws {
    let task = try makeTask(title: "Prepare café notes", tags: ["Writing"])
    let today = try CalendarDate("2026-07-27")

    #expect(TaskQuery(text: "CAFE").matches(task, today: today))
    #expect(TaskQuery(text: "writing").matches(task, today: today))
}

@Test func tagScopeRemainsCaseSensitive() throws {
    let task = try makeTask(tags: ["Swift"])
    let today = try CalendarDate("2026-07-27")

    #expect(TaskQuery(scope: .tag("Swift")).matches(task, today: today))
    #expect(!TaskQuery(scope: .tag("swift")).matches(task, today: today))
}
