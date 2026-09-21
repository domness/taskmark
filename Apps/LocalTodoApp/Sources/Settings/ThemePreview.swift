import SwiftUI

/// A small native task-list preview uses the same palette tokens as the workspace.
struct ThemePreview: View {
    let theme: AppTheme
    let scheme: ColorScheme
    let isSelected: Bool
    let select: () -> Void
    @ScaledMetric(relativeTo: .body) private var baseFontSize = 13.0

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "sun.max")
                        Image(systemName: "tray")
                        Image(systemName: "square.stack")
                    }
                    .foregroundStyle(color("--accent"))
                    .padding(12)
                    .frame(maxHeight: .infinity)
                    .background(color("--sidebar-background"))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today").font(theme.typography.font(.caption, weight: .semibold))
                        Label("Plan the week", systemImage: "circle")
                        Label("Review notes", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    }
                    .font(theme.typography.taskFont(scaledSize: sampleFontSize))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 112)
                .background(color("--background"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? color("--accent") : Color.secondary.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    ))
                HStack {
                    Text(theme.title).themeFont(.body, weight: .medium)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(color("--accent"))
                    }
                }
                Text(theme.summary).themeFont(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.title + ", " + theme.summary)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func color(_ token: String) -> Color {
        theme.tokens.color(token, scheme: scheme, fallback: .accentColor)
    }

    private var sampleFontSize: Double {
        baseFontSize * theme.tokens.number("--task-font-size", scheme: scheme, fallback: 13) / 13
    }
}
