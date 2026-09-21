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
            let draft = try #require(model.selectedTaskDraft)
            let root = TaskListView(model: model)
                .modifier(AppAppearanceModifier(model: model))
            let controller = NSHostingController(rootView: root)
            let window = NativeInputTestWindow(contentViewController: controller)
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 600, height: 400))
            defer { window.close() }
            try await presentForNativeInput(window)
            try await beginInlineEditing(model: model, draft: draft, window: window)

            for theme in [AppTheme.catppuccin, .dracula, .standard, .catppuccin] {
                model.preferences.theme = theme
                let size = theme == .catppuccin ? 14.0 : 13.0
                try await expectEditorFont(in: window, text: draft.title, theme: theme, size: size)
            }
            model.vaultAppearance = try VaultAppearance.parse(":root { --task-font-size: 18px; }")
            try await expectEditorFont(in: window, text: draft.title, theme: .catppuccin, size: 18)
        }
    }

    private func beginInlineEditing(model: WorkspaceModel, draft: TaskDraft, window: NSWindow) async throws {
        let host = try #require(window.contentView)
        try await waitForNativeUI("native task row presentation", in: window) {
            table(in: host)?.numberOfRows == 1
        }
        let table = try #require(table(in: host))
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        #expect(window.makeFirstResponder(table))
        try await waitForNativeUI("native task selection before editing", in: window) {
            table.selectedRow == 0 && model.selectedTaskPath == draft.path && window.firstResponder === table
        }
        model.beginInlineTitleEditing(at: draft.path)
        try await waitForNativeUI("inline field installed in the task row", in: window) {
            field(in: host, text: draft.title) != nil && model.inlineTitleEditingPath == draft.path
        }
        // This test measures the native editor font. Explicitly enter its editing
        // session instead of depending on automatic focus in a background test window.
        field(in: host, text: draft.title)?.selectText(nil)
        // Do not change the font environment while the inline field is still being inserted/focused.
        try await waitForNativeUI(
            "inline title editor ready before theme changes", in: window,
            diagnostics: {
                "inlinePath=\(String(describing: model.inlineTitleEditingPath)), "
                    + "field=\(field(in: host, text: draft.title) != nil), "
                    + "rowView=\(table.view(atColumn: 0, row: 0, makeIfNecessary: false) != nil), "
                    + "visible=\(model.visibleTasks.count), bounds=\(table.bounds)"
            },
            until: {
                let field = field(in: host, text: draft.title)
                return field?.currentEditor() != nil && field?.currentEditor() === window.firstResponder
            }
        )
    }

    @Test func semanticEditorFontsFollowTheAppearanceEnvironment() async throws {
        try await withWorkspace { model, _ in
            let controller = NSHostingController(rootView: VStack {
                TextField("Body sample", text: .constant("Body sample")).themeFont(.body)
                TextField("Heading sample", text: .constant("Heading sample")).themeFont(.headline)
            }.modifier(AppAppearanceModifier(model: model)))
            let window = NativeInputTestWindow(contentViewController: controller)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            try await presentForNativeInput(window)
            for theme in [AppTheme.catppuccin, .dracula, .standard] {
                model.preferences.theme = theme
                try await expectEditorFont(in: window, text: "Body sample", theme: theme)
                try await expectEditorFont(in: window, text: "Heading sample", theme: theme)
            }
        }
    }

    private func table(in view: NSView) -> NSTableView? {
        (view as? NSTableView) ?? view.subviews.lazy.compactMap { table(in: $0) }.first
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
