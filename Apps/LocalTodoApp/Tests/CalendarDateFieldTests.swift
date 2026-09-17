import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import Testing

@Test func calendarDateSuggestionsMatchTheReferenceWeek() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let monday = try #require(ISO8601DateFormatter().date(from: "2026-07-27T12:00:00Z"))

    let suggestions = CalendarDateSuggestion.options(now: monday, calendar: calendar)
    let dates = Dictionary(uniqueKeysWithValues: suggestions.compactMap { suggestion in
        suggestion.date.map { (suggestion.id, $0.description) }
    })

    #expect(dates[.today] == "2026-07-27")
    #expect(dates[.tomorrow] == "2026-07-28")
    #expect(dates[.laterThisWeek] == "2026-07-29")
    #expect(dates[.thisWeekend] == "2026-08-01")
    #expect(dates[.nextWeek] == "2026-08-03")
    #expect(suggestions.first { $0.id == .noDate }?.date == nil)
}

@Test func calendarDateSuggestionsAvoidMislabelingAWeekendDate() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let saturday = try #require(ISO8601DateFormatter().date(from: "2026-08-01T12:00:00Z"))

    let suggestions = CalendarDateSuggestion.options(now: saturday, calendar: calendar)

    #expect(!suggestions.contains { $0.id == .laterThisWeek })
    #expect(suggestions.first { $0.id == .thisWeekend }?.date?.description == "2026-08-01")
    #expect(suggestions.first { $0.id == .nextWeek }?.date?.description == "2026-08-03")
}
