import SwiftUI

extension EnvironmentValues {
    @Entry var vaultAppearance: VaultAppearance = AppTheme.standard.tokens

    @Entry var displayDateFormat: DisplayDateFormat = .system
}

struct AppAppearanceModifier: ViewModifier {
    let model: WorkspaceModel
    @Environment(\.colorScheme) private var systemScheme
    @ScaledMetric(relativeTo: .body) private var scaledBodySize = 13.0

    func body(content: Content) -> some View {
        let scheme = model.preferences.appearance.colorScheme ?? systemScheme
        let appearance = model.effectiveAppearance
        let configuredBodySize = appearance.number("--task-font-size", scheme: scheme, fallback: 13)
        let typography = model.preferences.theme.typography.scaled(
            toBodySize: scaledBodySize * configuredBodySize / 13
        )
        content
            .preferredColorScheme(model.preferences.appearance.colorScheme)
            .environment(\.vaultAppearance, appearance)
            .environment(\.themeTypography, typography)
            .font(typography.font(.body))
            .environment(\.displayDateFormat, model.preferences.dateFormat)
            .environment(\.calendar, model.planningCalendar)
            .environment(\.timeZone, model.vaultCalendar.timeZone)
            .tint(appearance.color("--accent", scheme: scheme, fallback: .accentColor))
    }
}

struct ThemeSurface: ViewModifier {
    let token: String
    @Environment(\.vaultAppearance) private var appearance
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background(appearance.color(token, scheme: scheme, fallback: Color(nsColor: .windowBackgroundColor)))
    }
}

extension View {
    func themeSurface(_ token: String = "--background") -> some View {
        modifier(ThemeSurface(token: token))
    }
}
