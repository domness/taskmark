import AppKit
import SwiftUI

/// One interface family per theme, retaining native semantic sizes and scalable text.
struct ThemeTypography: Equatable {
    let family: String?

    func font(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let font: Font = if let family {
            .custom(family, size: nativeSize(for: style), relativeTo: style)
        } else {
            .system(style)
        }
        return font.weight(weight ?? (style == .headline ? .semibold : .regular))
    }

    /// The row has already applied ScaledMetric, so do not scale its size a second time.
    func taskFont(scaledSize: Double) -> Font {
        guard let family else { return .system(size: scaledSize) }
        return .custom(family, fixedSize: scaledSize)
    }

    private func nativeSize(for style: Font.TextStyle) -> CGFloat {
        NSFont.preferredFont(forTextStyle: Self.nativeStyles[style] ?? .body).pointSize
    }

    private static let nativeStyles: [Font.TextStyle: NSFont.TextStyle] = [
        .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3,
        .headline: .headline, .subheadline: .subheadline, .callout: .callout,
        .caption: .caption1, .caption2: .caption2, .footnote: .footnote, .body: .body,
    ]
}

extension AppTheme {
    var typography: ThemeTypography {
        switch self {
        case .catppuccin: ThemeTypography(family: "Figtree")
        case .dracula: ThemeTypography(family: "Inter")
        default: ThemeTypography(family: nil)
        }
    }
}

extension EnvironmentValues {
    @Entry var themeTypography = ThemeTypography(family: nil)
}

private struct ThemeFont: ViewModifier {
    let style: Font.TextStyle
    let weight: Font.Weight?
    @Environment(\.themeTypography) private var typography

    func body(content: Content) -> some View {
        content.font(typography.font(style, weight: weight))
    }
}

extension View {
    func themeFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(ThemeFont(style: style, weight: weight))
    }
}
