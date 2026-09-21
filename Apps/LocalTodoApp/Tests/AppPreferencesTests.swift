import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
@Test func appPreferencesProjectSharedConfigurationValues() {
    let preferences = AppPreferences()
    #expect(preferences.weekStart == .monday)
    #expect(preferences.appearance == .system)
    preferences.weekStart = .saturday
    preferences.dateFormat = .dayFirst
    preferences.timeFormat = .twentyFourHour
    preferences.initialView = .upcoming
    preferences.appearance = .dark
    preferences.theme = .forest
    preferences.usesVaultStylesheet = false
    let restored = AppPreferences(values: preferences.values)
    #expect(restored.weekStart == .saturday)
    #expect(restored.dateFormat == .dayFirst)
    #expect(restored.timeFormat == .twentyFourHour)
    #expect(restored.initialView == .upcoming)
    #expect(restored.appearance == .dark)
    #expect(restored.theme == .forest)
    #expect(!restored.usesVaultStylesheet)
    restored.apply([:])
    let recovered = restored
    #expect(recovered.theme == .standard)
    #expect(recovered.weekStart == .monday)
}

@Test func dateAndTimeFormatsRespectCalendarTimezoneWithoutChangingDates() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    let date = try CalendarDate("2026-09-17")
    #expect(DisplayDateFormat.iso.string(date, calendar: calendar) == "2026-09-17")
    #expect(DisplayDateFormat.dayFirst.string(date, calendar: calendar) == "17/09/2026")
    #expect(DisplayDateFormat.monthFirst.string(date, calendar: calendar) == "09/17/2026")
    #expect(date.description == "2026-09-17")
    let instant = try #require(ISO8601DateFormatter().date(from: "2026-09-17T17:05:00Z"))
    #expect(DisplayTimeFormat.twelveHour.string(instant, calendar: calendar) == "1:05 PM")
    #expect(DisplayTimeFormat.twentyFourHour.string(instant, calendar: calendar) == "13:05")
}

@Test(arguments: [1, 2, 7])
func nextWeekHonorsConfiguredWeekStart(firstWeekday: Int) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    calendar.firstWeekday = firstWeekday
    let now = try #require(ISO8601DateFormatter().date(from: "2026-09-17T12:00:00Z"))
    let next = try #require(CalendarDateSuggestion.options(now: now, calendar: calendar).first { $0.id == .nextWeek }?
        .date)
    #expect(try calendar.component(.weekday, from: next.date(in: calendar)) == firstWeekday)
    #expect(try next > CalendarDate("2026-09-17"))
}

@MainActor
@Test func startupUsesPreferenceAndPlanningWeekDoesNotChangeRecurrenceCalendar() async throws {
    try await withWorkspace { model, _ in
        let original = model.vaultCalendar.firstWeekday
        model.preferences.initialView = .waiting
        model.preferences.weekStart = .saturday
        #expect(model.planningCalendar.firstWeekday == 7)
        #expect(model.vaultCalendar.firstWeekday == original)
        #expect(await model.flushPreferences())
        await model.restoreVault()
        #expect(model.route == .waiting)
    }
}

@MainActor
@Test func themesHavePairedSurfacesAndCustomTokensOverrideOnlySpecifiedValues() async throws {
    try await withWorkspace { model, _ in
        for theme in AppTheme.allCases {
            #expect(theme.tokens.light["--background"] != theme.tokens.dark["--background"])
            model.preferences.theme = theme
            #expect(model.effectiveAppearance == theme.tokens)
            model.vaultAppearance = try VaultAppearance.parse(":root { --background: #123456; --row-spacing: 8px; }")
            #expect(model.effectiveAppearance.light["--background"] == "#123456")
            #expect(model.effectiveAppearance.dark["--row-spacing"] == "8px")
            #expect(model.effectiveAppearance.light["--accent"] == theme.tokens.light["--accent"])
            #expect(model.effectiveAppearance.dark["--accent"] == theme.tokens.dark["--accent"])
            model.usesVaultStylesheet = false
            #expect(model.effectiveAppearance == theme.tokens)
            model.vaultAppearance = .init()
            model.usesVaultStylesheet = true
        }
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.dark.colorScheme == .dark)
        #expect(AppAppearance.light.colorScheme == .light)
    }
}

@MainActor
@Test func everySelectableThemePersistsAndRestoresWithIndependentAppearance() async throws {
    try await withWorkspace { model, root in
        for theme in AppTheme.allCases {
            for appearance in AppAppearance.allCases {
                model.preferences.theme = theme
                model.preferences.appearance = appearance
                #expect(await model.flushPreferences())
                let record = try await VaultStore(root: root).configurationRecord()
                let restored = AppPreferences(values: record.value.preferences)
                #expect(restored.theme == theme)
                #expect(restored.appearance == appearance)
            }
        }
    }
}
