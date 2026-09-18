import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test(arguments: [false, true])
func inspectorToggleRemainsSingleAcrossPresentationChanges(initiallyPresented: Bool) async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Inspect", vaultSession: model.vaultSession)
        model.isInspectorPresented = initiallyPresented
        let host = NSHostingController(rootView: WorkspaceView(model: model))
        let window = NSWindow(contentViewController: host)
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 1200, height: 700))
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        for presented in [initiallyPresented, !initiallyPresented, initiallyPresented, !initiallyPresented] {
            model.isInspectorPresented = presented
            try await Task.sleep(for: .milliseconds(300))
            let toolbar = try #require(window.toolbar)
            let toggles = toolbar.items.filter { $0.label.contains("Inspector") }
            let labels = toolbar.items.map { "\($0.itemIdentifier.rawValue): \($0.label)" }.joined(separator: ", ")
            #expect(toggles.count == 1, Comment(rawValue: labels))
            #expect(toggles.first?.label == (presented ? "Hide Inspector" : "Show Inspector"))
        }
    }
}
