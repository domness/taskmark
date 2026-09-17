import Foundation
import Observation

/// Device-local presentation preferences. The vault time zone is intentionally stored in its manifest instead.
@MainActor
@Observable
final class AppPreferences {
    var weekStart: WeekStart {
        didSet { defaults.set(weekStart.rawValue, forKey: "preferences.weekStart") }
    }

    var dateFormat: DisplayDateFormat {
        didSet { defaults.set(dateFormat.rawValue, forKey: "preferences.dateFormat") }
    }

    var timeFormat: DisplayTimeFormat {
        didSet { defaults.set(timeFormat.rawValue, forKey: "preferences.timeFormat") }
    }

    var initialView: InitialView {
        didSet { defaults.set(initialView.rawValue, forKey: "preferences.initialView") }
    }

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "preferences.appearance") }
    }

    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: "preferences.theme") }
    }

    var usesVaultStylesheet: Bool {
        didSet { defaults.set(usesVaultStylesheet, forKey: "preferences.vaultStylesheet") }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        weekStart = WeekStart(rawValue: defaults.integer(forKey: "preferences.weekStart")) ?? .monday
        dateFormat = DisplayDateFormat(rawValue: defaults.string(forKey: "preferences.dateFormat") ?? "") ?? .system
        timeFormat = DisplayTimeFormat(rawValue: defaults.string(forKey: "preferences.timeFormat") ?? "") ?? .system
        initialView = InitialView(rawValue: defaults.string(forKey: "preferences.initialView") ?? "") ?? .today
        appearance = AppAppearance(rawValue: defaults.string(forKey: "preferences.appearance") ?? "") ?? .system
        theme = AppTheme(rawValue: defaults.string(forKey: "preferences.theme") ?? "") ?? .standard
        usesVaultStylesheet = defaults.object(forKey: "preferences.vaultStylesheet") as? Bool ?? true
    }
}
