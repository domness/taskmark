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
            // Native inspector animation and toolbar propagation can outlast 300 ms.
            // Wait for the observable result, retaining a bounded failure for stale/duplicate items.
            let expectedLabel = presented ? "Hide Inspector" : "Show Inspector"
            for _ in 0 ..< 40 {
                try await Task.sleep(for: .milliseconds(50))
                let items = window.toolbar?.items.filter { $0.label.contains("Inspector") } ?? []
                if items.count == 1, items.first?.label == expectedLabel {
                    break
                }
            }
            let toolbar = try #require(window.toolbar)
            let toggles = toolbar.items.filter { $0.label.contains("Inspector") }
            let labels = toolbar.items.map { "\($0.itemIdentifier.rawValue): \($0.label)" }.joined(separator: ", ")
            #expect(toggles.count == 1, Comment(rawValue: labels))
            #expect(toggles.first?.label == (presented ? "Hide Inspector" : "Show Inspector"))
        }
    }
}
