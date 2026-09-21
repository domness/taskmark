import SwiftUI

extension EnvironmentValues {
    @Entry var vaultAppearance: VaultAppearance = AppTheme.standard.tokens

    @Entry var displayDateFormat: DisplayDateFormat = .system
}

struct AppAppearanceModifier: ViewModifier {
    let model: WorkspaceModel
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let scheme = model.preferences.appearance.colorScheme ?? systemScheme
        content
            .preferredColorScheme(model.preferences.appearance.colorScheme)
            .environment(\.vaultAppearance, model.effectiveAppearance)
            .environment(\.themeTypography, model.preferences.theme.typography)
            .font(model.preferences.theme.typography.font(.body))
            .environment(\.displayDateFormat, model.preferences.dateFormat)
            .environment(\.calendar, model.planningCalendar)
            .environment(\.timeZone, model.vaultCalendar.timeZone)
            .tint(model.effectiveAppearance.color("--accent", scheme: scheme, fallback: .accentColor))
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
