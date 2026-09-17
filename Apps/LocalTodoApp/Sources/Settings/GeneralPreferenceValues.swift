import Foundation
import LocalTodoDomain

enum WeekStart: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int {
        rawValue
    }

    var title: String {
        Calendar.current.weekdaySymbols[rawValue - 1]
    }
}

enum DisplayDateFormat: String, CaseIterable, Identifiable {
    case system, iso, dayFirst, monthFirst
    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: "System"
        case .iso: "YYYY-MM-DD"
        case .dayFirst: "DD/MM/YYYY"
        case .monthFirst: "MM/DD/YYYY"
        }
    }

    func string(_ value: CalendarDate, calendar: Calendar, locale: Locale = .current) -> String {
        guard let date = try? value.date(in: calendar) else { return value.description }
        return formatter(calendar: calendar, locale: locale).string(from: date)
    }

    func formatter(calendar: Calendar, locale: Locale = .current) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = self == .system ? locale : Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch self {
        case .system: formatter.dateStyle = .medium
        case .iso: formatter.dateFormat = "yyyy-MM-dd"
        case .dayFirst: formatter.dateFormat = "dd/MM/yyyy"
        case .monthFirst: formatter.dateFormat = "MM/dd/yyyy"
        }
        return formatter
    }
}

enum DisplayTimeFormat: String, CaseIterable, Identifiable {
    case system, twelveHour, twentyFourHour
    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: "System"
        case .twelveHour: "12-hour"
        case .twentyFourHour: "24-hour"
        }
    }

    func string(_ date: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = self == .system ? locale : Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch self {
        case .system: formatter.timeStyle = .short
        case .twelveHour: formatter.dateFormat = "h:mm a"
        case .twentyFourHour: formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }
}

enum InitialView: String, CaseIterable, Identifiable {
    case today, inbox, next, upcoming, waiting, someday, all, search
    var id: String {
        rawValue
    }

    var route: WorkspaceRoute {
        switch self {
        case .today: .today
        case .inbox: .inbox
        case .next: .next
        case .upcoming: .upcoming
        case .waiting: .waiting
        case .someday: .someday
        case .all: .all
        case .search: .search
        }
    }

    var title: String {
        route.title
    }
}
