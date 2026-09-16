import LocalTodoDomain
import Testing

@Test func dailyViewsUseCalendarBoundariesAndExplicitStatus() throws {
    let today = try CalendarDate("2026-09-16")
    let tasks = try [
        makeTask(path: "Tasks/a.md", status: .waiting, scheduled: CalendarDate("2026-09-17")),
        makeTask(path: "Tasks/b.md", status: .someday),
        makeTask(path: "Tasks/c.md", scheduled: today),
        makeTask(path: "Tasks/d.md", deadline: CalendarDate("2026-09-17")),
        makeTask(path: "Tasks/e.md", status: .done, scheduled: CalendarDate("2026-09-17")),
        makeTask(path: "Tasks/f.md", status: .canceled, deadline: CalendarDate("2026-09-17")),
    ]
    #expect(TaskQuery(scope: .upcoming, includeCompleted: true).results(from: tasks, today: today)
        .map(\.path.value) == ["Tasks/a.md", "Tasks/d.md"])
    #expect(TaskQuery(scope: .waiting).results(from: tasks, today: today).map(\.path.value) == ["Tasks/a.md"])
    #expect(TaskQuery(scope: .someday).results(from: tasks, today: today).map(\.path.value) == ["Tasks/b.md"])
    #expect(TaskQuery(scope: .today).results(from: tasks, today: today).map(\.path.value) == ["Tasks/c.md"])
}

@Test func combinedFiltersUseAndAcrossFieldsOrWithinStatusAndPriority() throws {
    var filters = TaskFilters()
    filters.project = try VaultPath("Projects/Exact.md")
    filters.statuses = [.next, .waiting]
    filters.priorities = [.p1, .p2]
    filters.tags = ["work", "desk"]
    filters.scheduled = try DateRange(start: CalendarDate("2026-09-16"), end: CalendarDate("2026-09-20"))
    filters.deadline = try DateRange(end: CalendarDate("2026-09-30"))
    let match = try makeTask(
        status: .waiting,
        priority: .p2,
        scheduled: CalendarDate("2026-09-16"),
        deadline: CalendarDate("2026-09-30"),
        project: filters.project,
        tags: ["desk", "work", "extra"]
    )
    let query = TaskQuery(filters: filters)
    let today = try CalendarDate("2026-09-16")
    #expect(query.matches(match, today: today))
    var patch = TaskPatch()
    patch.project = try .set(VaultPath("Projects/exact.md"))
    #expect(try !query.matches(patch.applying(to: match, now: testNow), today: today))
    patch = TaskPatch()
    patch.tags = .set(["work"])
    #expect(try !query.matches(patch.applying(to: match, now: testNow), today: today))
    patch = TaskPatch()
    patch.scheduled = .set(nil)
    #expect(try !query.matches(patch.applying(to: match, now: testNow), today: today))
}

@Test(arguments: [TaskSort.priority, .scheduled, .deadline])
func sortingPlacesMissingValuesLastAndBreaksTiesByExactPath(sort: TaskSort) throws {
    let tasks = try [
        makeTask(path: "Tasks/z.md"),
        makeTask(
            path: "Tasks/b.md",
            priority: .p1,
            scheduled: CalendarDate("2026-01-01"),
            deadline: CalendarDate("2026-01-01")
        ),
        makeTask(
            path: "Tasks/a.md",
            priority: .p1,
            scheduled: CalendarDate("2026-01-01"),
            deadline: CalendarDate("2026-01-01")
        ),
        makeTask(
            path: "Tasks/c.md",
            priority: .p3,
            scheduled: CalendarDate("2026-02-01"),
            deadline: CalendarDate("2026-02-01")
        ),
    ]
    #expect(try TaskQuery(sort: sort).results(from: tasks, today: CalendarDate("2026-09-16"))
        .map(\.path.value) == ["Tasks/a.md", "Tasks/b.md", "Tasks/c.md", "Tasks/z.md"])
}

@Test func sortingSupportsTitlesAndNewestEdits() throws {
    let zebra = try makeTask(path: "Tasks/a.md", title: "Zebra")
    let apple = try makeTask(path: "Tasks/z.md", title: "Apple")
    let edited = try TaskPatch().applying(to: apple, now: testNow.addingTimeInterval(60))
    let today = try CalendarDate("2026-09-16")
    #expect(TaskQuery(sort: .title).results(from: [zebra, apple], today: today).first?.title == "Apple")
    #expect(TaskQuery(sort: .updated).results(from: [zebra, edited], today: today).first?.path == apple.path)
}
