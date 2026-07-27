import Foundation
import LocalTodoDomain

struct CalendarDateSuggestion: Identifiable, Equatable {
    enum Kind: CaseIterable, Hashable {
        case today
        case tomorrow
        case laterThisWeek
        case thisWeekend
        case nextWeek
        case noDate
    }

    let id: Kind
    let title: String
    let systemImage: String
    let date: CalendarDate?

    static func options(now: Date, calendar: Calendar) -> [Self] {
        guard let today = try? CalendarDate(date: now, calendar: calendar) else { return [] }
        let weekday = calendar.component(.weekday, from: now)
        var options = [
            suggestion(.today, title: "Today", systemImage: "calendar.circle", date: today),
            suggestion(
                .tomorrow,
                title: "Tomorrow",
                systemImage: "sunrise",
                date: adding(1, to: today, calendar: calendar)
            ),
        ]
        if let offset = laterThisWeekOffset(for: weekday) {
            options.append(suggestion(
                .laterThisWeek,
                title: "Later this week",
                systemImage: "calendar",
                date: adding(offset, to: today, calendar: calendar)
            ))
        }
        options.append(contentsOf: remainingOptions(today: today, weekday: weekday, calendar: calendar))
        return options
    }

    private static func remainingOptions(
        today: CalendarDate,
        weekday: Int,
        calendar: Calendar
    ) -> [Self] {
        // Local Todo's planning week starts Monday, and its weekend starts Saturday.
        let weekendOffset = weekday == 1 || weekday == 7 ? 0 : 7 - weekday
        let nextWeekOffset = weekday == 2 ? 7 : (9 - weekday) % 7
        return [
            suggestion(
                .thisWeekend,
                title: "This weekend",
                systemImage: "cup.and.saucer",
                date: adding(weekendOffset, to: today, calendar: calendar)
            ),
            suggestion(
                .nextWeek,
                title: "Next week",
                systemImage: "arrow.right.square",
                date: adding(nextWeekOffset, to: today, calendar: calendar)
            ),
            suggestion(.noDate, title: "No Date", systemImage: "xmark.circle", date: nil),
        ]
    }

    private static func laterThisWeekOffset(for weekday: Int) -> Int? {
        switch weekday {
        case 2 ... 4: 2
        case 5: 1
        default: nil
        }
    }

    private static func suggestion(
        _ id: Kind,
        title: String,
        systemImage: String,
        date: CalendarDate?
    ) -> Self {
        Self(id: id, title: title, systemImage: systemImage, date: date)
    }

    private static func adding(_ days: Int, to date: CalendarDate, calendar: Calendar) -> CalendarDate? {
        try? date.adding(DateComponents(day: days), calendar: calendar)
    }
}
