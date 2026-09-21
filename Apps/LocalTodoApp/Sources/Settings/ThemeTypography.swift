import AppKit
import SwiftUI

/// One interface family per theme, retaining native semantic sizes and scalable text.
struct ThemeTypography: Equatable {
    let family: String?
    private let sizeScale: CGFloat

    init(family: String?, sizeScale: Double = 1) {
        self.family = family
        self.sizeScale = CGFloat(sizeScale)
    }

    func font(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        design: ThemeFontDesign = .proportional
    ) -> Font {
        let size = nativeSize(for: style) * sizeScale
        let font: Font = switch design {
        case .monospaced:
            .system(size: size, design: .monospaced)
        case .monospacedDigits:
            proportionalFont(style, size: size).monospacedDigit()
        case .proportional:
            proportionalFont(style, size: size)
        }
        return font.weight(weight ?? (style == .headline ? .semibold : .regular))
    }

    func scaled(toBodySize size: Double) -> Self {
        Self(family: family, sizeScale: size / 13)
    }

    private func nativeSize(for style: Font.TextStyle) -> CGFloat {
        NSFont.preferredFont(forTextStyle: Self.nativeStyles[style] ?? .body).pointSize
    }

    private func proportionalFont(_ style: Font.TextStyle, size: CGFloat) -> Font {
        if let family {
            // The scene root has already applied accessibility scaling to this size.
            return .custom(family, fixedSize: size)
        }
        return sizeScale == 1 ? .system(style) : .system(size: size)
    }

    private static let nativeStyles: [Font.TextStyle: NSFont.TextStyle] = [
        .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3,
        .headline: .headline, .subheadline: .subheadline, .callout: .callout,
        .caption: .caption1, .caption2: .caption2, .footnote: .footnote, .body: .body,
    ]
}

enum ThemeFontDesign {
    case proportional, monospaced, monospacedDigits
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
    let design: ThemeFontDesign
    @Environment(\.themeTypography) private var typography

    func body(content: Content) -> some View {
        content.font(typography.font(style, weight: weight, design: design))
    }
}

extension View {
    func themeFont(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        design: ThemeFontDesign = .proportional
    ) -> some View {
        modifier(ThemeFont(style: style, weight: weight, design: design))
    }
}
