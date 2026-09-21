import AppKit
import CoreText
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Suite("Theme typography")
struct ThemeTypographyTests {
    @Test func bundledFontsResolveWithRealBoldAndItalicFaces() throws {
        #expect(Bundle.main.object(forInfoDictionaryKey: "ATSApplicationFontsPath") as? String == "Fonts")
        for family in ["Inter", "Figtree"] {
            let regular = try #require(NSFont(name: family, size: 13))
            #expect(regular.familyName == family)
            let bold = NSFontManager.shared.convert(regular, toHaveTrait: .boldFontMask)
            let italic = NSFontManager.shared.convert(regular, toHaveTrait: .italicFontMask)
            #expect(NSFontManager.shared.traits(of: bold).contains(.boldFontMask))
            #expect(NSFontManager.shared.traits(of: italic).contains(.italicFontMask))
            for font in [regular, bold, italic] {
                #expect(font.familyName == family)
                let url = try #require(CTFontCopyAttribute(font as CTFont, kCTFontURLAttribute) as? URL)
                let bundledURL = try #require(Bundle.main.url(
                    forResource: url.deletingPathExtension().lastPathComponent,
                    withExtension: "ttf", subdirectory: "Fonts"
                ))
                #expect(url.standardizedFileURL == bundledURL.standardizedFileURL)
            }
            let license = try #require(Bundle.main.url(
                forResource: "\(family)-OFL", withExtension: "txt", subdirectory: "Fonts"
            ))
            #expect(try String(contentsOf: license, encoding: .utf8).contains("SIL OPEN FONT LICENSE"))
        }
    }

    @Test func themeSizingRetainsStylesheetPrecedenceAndResetsOnSwitch() async throws {
        try await withWorkspace { model, _ in
            for theme in AppTheme.allCases {
                model.preferences.theme = theme
                for scheme in [ColorScheme.light, .dark] {
                    let expected = theme == .catppuccin ? 14.0 : 13.0
                    #expect(model.effectiveAppearance
                        .number("--task-font-size", scheme: scheme, fallback: 0) == expected)
                }
            }
            model.preferences.theme = .catppuccin
            model.vaultAppearance = try VaultAppearance.parse(":root { --task-font-size: 17px; }")
            for theme in [AppTheme.catppuccin, .dracula, .standard] {
                model.preferences.theme = theme
                for scheme in [ColorScheme.light, .dark] {
                    #expect(model.effectiveAppearance.number("--task-font-size", scheme: scheme, fallback: 0) == 17)
                }
            }
            model.preferences.theme = .catppuccin
            model.usesVaultStylesheet = false
            #expect(model.effectiveAppearance.number("--task-font-size", scheme: .dark, fallback: 0) == 14)
            model.preferences.theme = .standard
            #expect(model.effectiveAppearance.number("--task-font-size", scheme: .dark, fallback: 0) == 13)
        }
    }

    @Test func nativeEditorsFollowThemeSwitchesAndRowSizeOverrides() async throws {
        try await withWorkspace { model, _ in
            model.route = .inbox
            await model.createTask(title: "Theme font sample", vaultSession: model.vaultSession)
            let path = try #require(model.selectedTaskPath)
            let draft = try #require(model.selectedTaskDraft)
            let task = try #require(model.snapshot?.tasks[path]?.value)
            let root = VStack {
                TaskRow(model: model, task: task, displayOptions: .defaults(for: .inbox), onSelect: {})
                TextField("Body sample", text: .constant("Body sample"))
                    .themeFont(.body)
                TextField("Heading sample", text: .constant("Heading sample"))
                    .themeFont(.headline)
            }
            .modifier(AppAppearanceModifier(model: model))
            let controller = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: controller)
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 500, height: 260))
            defer { window.close() }
            try await presentForNativeInput(window)
            try await beginInlineEditing(model: model, draft: draft, window: window)

            for theme in [AppTheme.catppuccin, .dracula, .standard, .catppuccin] {
                model.preferences.theme = theme
                let size = theme == .catppuccin ? 14.0 : 13.0
                try await expectEditorFont(in: window, text: draft.title, theme: theme, size: size)
                try await expectEditorFont(in: window, text: "Body sample", theme: theme)
                try await expectEditorFont(in: window, text: "Heading sample", theme: theme)
            }
            model.vaultAppearance = try VaultAppearance.parse(":root { --task-font-size: 18px; }")
            try await expectEditorFont(in: window, text: draft.title, theme: .catppuccin, size: 18)
        }
    }

    private func beginInlineEditing(model: WorkspaceModel, draft: TaskDraft, window: NSWindow) async throws {
        let host = try #require(window.contentView)
        try await waitForNativeUI("typography host presentation", in: window) {
            window.isVisible && field(in: host, text: "Body sample") != nil
        }
        field(in: host, text: "Body sample")?.selectText(nil)
        try await waitForNativeUI("initial typography field focus", in: window) {
            (window.firstResponder as? NSTextView)?.string == "Body sample"
        }
        model.beginInlineTitleEditing(at: draft.path)
        // Do not change the font environment while the inline field is still being inserted/focused.
        try await waitForNativeUI(
            "inline title editor ready before theme changes", in: window,
            diagnostics: { "inlinePath=\(String(describing: model.inlineTitleEditingPath))" },
            until: {
                let field = field(in: host, text: draft.title)
                return field?.currentEditor() != nil && field?.currentEditor() === window.firstResponder
            }
        )
    }

    private func expectEditorFont(
        in window: NSWindow,
        text: String,
        theme: AppTheme,
        size: Double? = nil
    ) async throws {
        let view = try #require(window.contentView)
        let expectedFamily = theme.typography.family ?? NSFont.systemFont(ofSize: 13).familyName
        try await waitForNativeUI("\(theme) font for \(text)", in: window) {
            let font = field(in: view, text: text)?.font
            let matchesSize = size.map { abs((font?.pointSize ?? 0) - CGFloat($0)) < 0.01 } ?? true
            return font != nil && font?.familyName == expectedFamily && matchesSize
        }
        let font = try #require(field(in: view, text: text)?.font, "Missing native field: \(text), theme: \(theme)")
        #expect(font.familyName == expectedFamily)
        if let size {
            #expect(abs(font.pointSize - CGFloat(size)) < 0.01)
        }
    }

    private func field(in view: NSView, text: String) -> NSTextField? {
        if let field = view as? NSTextField, field.stringValue == text {
            return field
        }
        return view.subviews.lazy.compactMap { field(in: $0, text: text) }.first
    }
}
