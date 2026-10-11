import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Suite("Workspace tab typography")
struct WorkspaceTabTypographyTests {
    @Test func nativeTabsFollowThemeSwitchesAndStylesheetSizes() async throws {
        try await withWorkspace { model, _ in
            let root = WorkspaceTabBar(
                model: model, width: 400,
                tabs: [.route(.today), .route(.upcoming)], selection: .route(.today),
                onSelect: { _ in }, onClose: { _ in }
            ).modifier(AppAppearanceModifier(model: model))
            let window = NativeInputTestWindow(contentViewController: NSHostingController(rootView: root))
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 500, height: 100))
            defer { window.close() }
            try await presentForNativeInput(window)
            let host = try #require(window.contentView)
            for theme in [AppTheme.catppuccin, .dracula, .standard] {
                model.preferences.theme = theme
                let size = theme == .catppuccin ? 14.0 : 13.0
                try await expectFonts(in: host, window: window, family: theme.fontFamily, size: size)
            }
            model.preferences.theme = .catppuccin
            model.vaultAppearance = try VaultAppearance.parse(":root { --task-font-size: 24px; }")
            try await expectFonts(in: host, window: window, family: "Figtree", size: 24)
        }
    }

    private func expectFonts(in host: NSView, window: NSWindow, family: String?, size: Double) async throws {
        try await waitForNativeUI("themed tab fonts", in: window) {
            let buttons = descendants(in: host).filter { ["Today", "Upcoming"].contains($0.title) }
            return buttons.count == 2 && buttons.allSatisfy {
                $0.font?.familyName == (family ?? NSFont.systemFont(ofSize: size).familyName)
                    && $0.font?.pointSize == CGFloat(size)
            }
        }
    }

    private func descendants(in view: NSView) -> [NSButton] {
        ((view as? NSButton).map { [$0] } ?? []) + view.subviews.flatMap { descendants(in: $0) }
    }
}
