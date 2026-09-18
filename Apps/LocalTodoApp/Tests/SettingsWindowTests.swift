import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test func settingsSceneAllowsUserResizing() async throws {
    let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
    let trigger = NSWindow(contentViewController: NSHostingController(rootView: OpenSettingsForTest()))
    trigger.isReleasedWhenClosed = false
    trigger.orderFront(nil)
    defer { trigger.close() }
    for _ in 0 ..< 20 {
        if NSApp.windows.contains(where: { $0 !== trigger && !existing.contains(ObjectIdentifier($0)) }) {
            break
        }
        try await Task.sleep(for: .milliseconds(50))
    }
    let settings = try #require(NSApp.windows.first {
        $0 !== trigger && !existing.contains(ObjectIdentifier($0)) && $0.isVisible
    })
    defer { settings.close() }
    try await Task.sleep(for: .milliseconds(150))
    #expect(settings.styleMask.contains(.resizable))
    #expect(settings.contentMaxSize.width > 1000)
    #expect(settings.contentMaxSize.height > 800)
    settings.setContentSize(NSSize(width: 1000, height: 800))
    try await Task.sleep(for: .milliseconds(100))
    let content = try #require(settings.contentView)
    #expect(content.bounds.width >= 1000)
    #expect(content.bounds.height >= 800)
}

private struct OpenSettingsForTest: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear.frame(width: 1, height: 1).onAppear { openSettings() }
    }
}
