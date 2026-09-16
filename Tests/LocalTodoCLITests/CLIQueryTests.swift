@testable import LocalTodoCLI
import LocalTodoDomain
import Testing

@Test func cliBuildsTheSameCombinedQuery() throws {
    let options = try TaskQueryOptions.parse([
        "--view", "upcoming", "--project", "Projects/Exact.md", "--status", "waiting", "--status", "next",
        "--priority", "p1", "--priority", "none", "--tag", "work", "--tag", "desk",
        "--scheduled-from", "2026-09-16", "--scheduled-through", "2026-09-20",
        "--deadline-on", "2026-09-30", "--sort", "deadline",
    ])
    let query = try options.query()
    #expect(query.scope == .upcoming)
    #expect(query.sort == .deadline)
    #expect(query.filters.statuses == [.waiting, .next])
    #expect(query.filters.priorities == [.p1])
    #expect(query.filters.includesNoPriority)
    #expect(query.filters.tags == ["work", "desk"])
    #expect(query.filters.scheduled.isValid)
    #expect(query.filters.deadline.start == query.filters.deadline.end)
}

@Test(arguments: [
    ["--sort", "unknown"], ["--view", "unknown"],
    ["--scheduled-from", "2026-09-20", "--scheduled-through", "2026-09-16"],
    ["--deadline-on", "2026-09-16", "--deadline-from", "2026-09-16"],
])
func cliRejectsInvalidQueryOptions(arguments: [String]) throws {
    let options = try TaskQueryOptions.parse(arguments)
    #expect(throws: (any Error).self) { try options.query() }
}
