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
    let screen = try #require(settings.screen)
    // AppKit constrains windows to the visible screen, including on small CI displays.
    let available = settings.contentRect(forFrameRect: screen.visibleFrame).size
    let large = NSSize(width: min(1000, available.width - 20), height: min(800, available.height - 20))
    let small = NSSize(
        width: max(settings.contentMinSize.width, large.width - 40),
        height: max(settings.contentMinSize.height, large.height - 40)
    )
    try #require(large.width - small.width >= 10)
    try #require(large.height - small.height >= 10)
    try await resize(settings, to: small)
    try await resize(settings, to: large)
    try await resize(settings, to: small)
}

@MainActor
private func resize(_ settings: NSWindow, to size: NSSize) async throws {
    settings.setContentSize(size)
    let content = try #require(settings.contentView)
    for _ in 0 ..< 40 {
        try await Task.sleep(for: .milliseconds(50))
        if abs(content.bounds.width - size.width) < 1, abs(content.bounds.height - size.height) < 1 {
            break
        }
    }
    #expect(abs(content.bounds.width - size.width) < 1)
    #expect(abs(content.bounds.height - size.height) < 1)
}

private struct OpenSettingsForTest: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear.frame(width: 1, height: 1).onAppear { openSettings() }
    }
}
