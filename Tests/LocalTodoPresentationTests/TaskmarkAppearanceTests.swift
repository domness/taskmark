import LocalTodoPresentation
import SwiftUI
import Testing

@Test func everyThemeProvidesPairedSurfacesAndExpectedFont() {
    for theme in TaskmarkTheme.allCases {
        #expect(theme.tokens.light["--background"] != nil)
        #expect(theme.tokens.dark["--background"] != nil)
        #expect(theme.tokens.light["--selection-background"] != nil)
        #expect(theme.tokens.dark["--selection-background"] != nil)
        #expect(theme.tokens.light["--accent"] != theme.tokens.dark["--accent"])

        let lightSelection = channelSum(theme.tokens.light["--selection-background"])
        #expect(lightSelection < channelSum(theme.tokens.light["--background"]))
        #expect(lightSelection < channelSum(theme.tokens.light["--sidebar-background"]))

        let darkSelection = channelSum(theme.tokens.dark["--selection-background"])
        #expect(darkSelection > channelSum(theme.tokens.dark["--background"]))
        #expect(darkSelection > channelSum(theme.tokens.dark["--sidebar-background"]))
    }
    #expect(TaskmarkTheme.catppuccin.fontFamily == "Figtree")
    #expect(TaskmarkTheme.dracula.fontFamily == "Inter")
    #expect(TaskmarkTheme.standard.fontFamily == nil)
}

private func channelSum(_ value: String?) -> UInt32 {
    guard let value, let color = UInt32(value.dropFirst(), radix: 16) else { return 0 }
    return (color >> 16) + ((color >> 8) & 255) + (color & 255)
}

@Test func stylesheetParsingPreservesAppearancePrecedence() throws {
    let parsed = try TaskmarkAppearance.parse("""
    :root { --accent: #123456; --selection-background: #d8dde3; --row-spacing: 7px; }
    :root[data-appearance=dark] { --background: #111122; }
    """)
    #expect(parsed.light["--accent"] == "#123456")
    #expect(parsed.dark["--accent"] == "#123456")
    #expect(parsed.light["--selection-background"] == "#d8dde3")
    #expect(parsed.dark["--selection-background"] == "#d8dde3")
    #expect(parsed.light["--background"] == nil)
    #expect(parsed.dark["--background"] == "#111122")
}

@Test func unsupportedCSSIsRejected() {
    #expect(throws: TaskmarkAppearanceError.self) {
        try TaskmarkAppearance.parse(".task { color: red; }")
    }
}
