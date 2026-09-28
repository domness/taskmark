import LocalTodoPresentation
import SwiftUI
import Testing

@Test func everyThemeProvidesPairedSurfacesAndExpectedFont() {
    for theme in TaskmarkTheme.allCases {
        #expect(theme.tokens.light["--background"] != nil)
        #expect(theme.tokens.dark["--background"] != nil)
        #expect(theme.tokens.light["--accent"] != theme.tokens.dark["--accent"])
    }
    #expect(TaskmarkTheme.catppuccin.fontFamily == "Figtree")
    #expect(TaskmarkTheme.dracula.fontFamily == "Inter")
    #expect(TaskmarkTheme.standard.fontFamily == nil)
}

@Test func stylesheetParsingPreservesAppearancePrecedence() throws {
    let parsed = try TaskmarkAppearance.parse("""
    :root { --accent: #123456; --row-spacing: 7px; }
    :root[data-appearance=dark] { --background: #111122; }
    """)
    #expect(parsed.light["--accent"] == "#123456")
    #expect(parsed.dark["--accent"] == "#123456")
    #expect(parsed.light["--background"] == nil)
    #expect(parsed.dark["--background"] == "#111122")
}

@Test func unsupportedCSSIsRejected() {
    #expect(throws: TaskmarkAppearanceError.self) {
        try TaskmarkAppearance.parse(".task { color: red; }")
    }
}
