import SwiftUI

/// A small native task-list preview uses the same palette tokens as the workspace.
struct ThemePreview: View {
    let theme: AppTheme
    let scheme: ColorScheme
    let isSelected: Bool
    let select: () -> Void

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
                        Text("Today").font(.caption.weight(.semibold))
                        Label("Plan the week", systemImage: "circle")
                        Label("Review notes", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    }
                    .font(.caption)
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
                    Text(theme.title).font(.body.weight(.medium))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(color("--accent"))
                    }
                }
                Text(theme.summary).font(.caption).foregroundStyle(.secondary)
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
}
