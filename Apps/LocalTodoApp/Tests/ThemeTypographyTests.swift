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
            window.makeKeyAndOrderFront(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(100))
            model.beginInlineTitleEditing(at: path)

            for theme in [AppTheme.catppuccin, .dracula, .standard, .catppuccin] {
                model.preferences.theme = theme
                let size = theme == .catppuccin ? 14.0 : 13.0
                try await expectEditorFont(in: controller.view, text: draft.title, theme: theme, size: size)
                try await expectEditorFont(in: controller.view, text: "Body sample", theme: theme)
                try await expectEditorFont(in: controller.view, text: "Heading sample", theme: theme)
            }
            model.vaultAppearance = try VaultAppearance.parse(":root { --task-font-size: 18px; }")
            try await expectEditorFont(in: controller.view, text: draft.title, theme: .catppuccin, size: 18)
        }
    }

    private func expectEditorFont(in view: NSView, text: String, theme: AppTheme, size: Double? = nil) async throws {
        let expectedFamily = theme.typography.family ?? NSFont.systemFont(ofSize: 13).familyName
        for _ in 0 ..< 40 {
            view.layoutSubtreeIfNeeded()
            let font = field(in: view, text: text)?.font
            let matchesSize = size == nil || font?.pointSize == size.map { CGFloat($0) }
            if font?.familyName == expectedFamily, matchesSize {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        let font = try #require(field(in: view, text: text)?.font, "Missing native field: \(text), theme: \(theme)")
        #expect(font.familyName == expectedFamily)
        if let size {
            #expect(font.pointSize == size)
        }
    }

    private func field(in view: NSView, text: String) -> NSTextField? {
        if let field = view as? NSTextField, field.stringValue == text {
            return field
        }
        return view.subviews.lazy.compactMap { field(in: $0, text: text) }.first
    }
}
