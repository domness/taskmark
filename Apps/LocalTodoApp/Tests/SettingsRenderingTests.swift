import AppKit
import Foundation
@testable import LocalTodoApp
import SwiftUI
import Testing

/// Opt-in visual evidence: TEST_RUNNER_LOCALTODO_SETTINGS_CAPTURES=/existing/directory xcodebuild ... test.
/// Captures isolated native views; it does not alter the user's preferences or vault.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["LOCALTODO_SETTINGS_CAPTURES"] != nil))
func captureSettingsAppearances() async throws {
    let directory = try #require(ProcessInfo.processInfo.environment["LOCALTODO_SETTINGS_CAPTURES"])
    try await withWorkspace { model, _ in
        for appearance in [AppAppearance.light, .dark] {
            model.preferences.appearance = appearance
            model.preferences.theme = .standard
            try await captureSettings(model, section: .general, directory: directory)
            for theme in AppTheme.allCases {
                model.preferences.theme = theme
                try await captureSettings(model, section: .theme, directory: directory)
            }
        }
    }
}

@MainActor
private func captureSettings(_ model: WorkspaceModel, section: SettingsSection, directory: String) async throws {
    let view = NSHostingView(rootView: SettingsView(model: model, initialSection: section)
        .modifier(AppAppearanceModifier(model: model)))
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: model.preferences.appearance == .dark ? .darkAqua : .aqua)
    window.contentView = view
    window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    try await Task.sleep(for: .milliseconds(200))
    let palette = model.preferences.theme.rawValue
    let name = "settings-\(section.rawValue)-\(palette)-\(model.preferences.appearance.rawValue).png"
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = [
        "-x",
        "-o",
        "-l",
        String(window.windowNumber),
        URL(fileURLWithPath: directory).appendingPathComponent(name).path,
    ]
    try capture.run()
    capture.waitUntilExit()
    #expect(capture.terminationStatus == 0)
}
