import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test func newVaultWindowSceneCreatesIndependentWorkspaces() async throws {
    let first = try await openVaultScene()
    defer { first.close() }
    let second = try await openVaultScene()
    defer { second.close() }
    let firstModel = try #require((first.delegate as? WorkspaceWindowDelegate)?.model)
    let secondModel = try #require((second.delegate as? WorkspaceWindowDelegate)?.model)
    #expect(first !== second)
    #expect(firstModel !== secondModel)
    #expect(firstModel.preferences !== secondModel.preferences)
    #expect(secondModel.rootURL == nil)
    #expect(first.tabbingMode == .disallowed)
    #expect(second.tabbingMode == .disallowed)
    let menu = try #require(NSApp.mainMenu)
    let command = try #require(vaultWindowCommand(in: menu))
    #expect(command.keyEquivalent == "n")
    #expect(command.keyEquivalentModifierMask.contains([.command, .shift]))
}

@MainActor
private func openVaultScene() async throws -> NSWindow {
    let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
    let trigger = NSWindow(contentViewController: NSHostingController(rootView: OpenVaultForTest()))
    trigger.isReleasedWhenClosed = false
    trigger.orderFront(nil)
    defer { trigger.close() }
    for _ in 0 ..< 40 {
        if let window = NSApp.windows.first(where: {
            !existing.contains(ObjectIdentifier($0)) && $0.delegate is WorkspaceWindowDelegate
        }) {
            window.isReleasedWhenClosed = false
            return window
        }
        try await Task.sleep(for: .milliseconds(50))
    }
    throw VaultWindowTestError.windowDidNotOpen
}

private enum VaultWindowTestError: Error {
    case windowDidNotOpen
}

private struct OpenVaultForTest: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear.frame(width: 1, height: 1).onAppear { openWindow(id: "vault") }
    }
}

@MainActor
private func vaultWindowCommand(in menu: NSMenu) -> NSMenuItem? {
    for item in menu.items {
        if item.title == "New Vault Window" {
            return item
        }
        if let submenu = item.submenu, let command = vaultWindowCommand(in: submenu) {
            return command
        }
    }
    return nil
}
