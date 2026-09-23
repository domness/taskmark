import LocalTodoMarkdown
import Observation

/// A window's projection of its vault's canonical preferences. Changes are saved by WorkspaceModel.
@MainActor
@Observable
final class AppPreferences {
    var weekStart: WeekStart = .monday {
        didSet { changed("week_start", .integer(weekStart.rawValue)) }
    }

    var dateFormat: DisplayDateFormat = .system {
        didSet { changed("date_format", .string(dateFormat.rawValue)) }
    }

    var timeFormat: DisplayTimeFormat = .system {
        didSet { changed("time_format", .string(timeFormat.rawValue)) }
    }

    var initialView: InitialView = .today {
        didSet { changed("initial_view", .string(initialView.rawValue)) }
    }

    var appearance: AppAppearance = .system {
        didSet { changed("appearance", .string(appearance.rawValue)) }
    }

    var theme: AppTheme = .standard {
        didSet { changed("theme", .string(theme.rawValue)) }
    }

    var usesVaultStylesheet = true {
        didSet { changed("vault_stylesheet", .bool(usesVaultStylesheet)) }
    }

    var showsDockBadge = false {
        didSet { changed("dock_badge", .bool(showsDockBadge)) }
    }

    @ObservationIgnored var onChange: ((String, ConfigurationValue) -> Void)?
    @ObservationIgnored private var isApplying = false

    init(values: [String: ConfigurationValue] = [:]) {
        apply(values)
    }

    var values: [String: ConfigurationValue] {
        [
            "week_start": .integer(weekStart.rawValue),
            "date_format": .string(dateFormat.rawValue),
            "time_format": .string(timeFormat.rawValue),
            "initial_view": .string(initialView.rawValue),
            "appearance": .string(appearance.rawValue),
            "theme": .string(theme.rawValue),
            "vault_stylesheet": .bool(usesVaultStylesheet),
            "dock_badge": .bool(showsDockBadge),
        ]
    }

    func apply(_ values: [String: ConfigurationValue]) {
        isApplying = true
        defer { isApplying = false }
        weekStart = WeekStart(rawValue: (try? values["week_start"]?.decode(Int.self)) ?? 2) ?? .monday
        dateFormat = DisplayDateFormat(rawValue: string("date_format", in: values)) ?? .system
        timeFormat = DisplayTimeFormat(rawValue: string("time_format", in: values)) ?? .system
        initialView = InitialView(rawValue: string("initial_view", in: values)) ?? .today
        appearance = AppAppearance(rawValue: string("appearance", in: values)) ?? .system
        theme = AppTheme(rawValue: string("theme", in: values)) ?? .standard
        usesVaultStylesheet = (try? values["vault_stylesheet"]?.decode(Bool.self)) ?? true
        showsDockBadge = (try? values["dock_badge"]?.decode(Bool.self)) ?? false
    }

    private func changed(_ key: String, _ value: ConfigurationValue) {
        if !isApplying {
            onChange?(key, value)
        }
    }

    private func string(_ key: String, in values: [String: ConfigurationValue]) -> String {
        (try? values[key]?.decode(String.self)) ?? ""
    }
}
