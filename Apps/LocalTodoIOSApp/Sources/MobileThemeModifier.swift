import SwiftUI

struct MobileThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let workspace: MobileWorkspace

    func body(content: Content) -> some View {
        let appearance = workspace.effectiveAppearance
        let background = appearance.color("--background", scheme: colorScheme, fallback: Color(.systemBackground))
        let accent = appearance.color("--accent", scheme: colorScheme, fallback: .accentColor)
        let size = workspace.mobileFontSize(for: colorScheme)
        content
            .font(workspace.theme.fontFamily.map { .custom($0, size: size, relativeTo: .body) } ?? .body)
            .tint(accent)
            .background(background.ignoresSafeArea())
    }
}
