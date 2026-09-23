import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test(arguments: [false, true], [840.0, 1120.0, 1600.0])
func inspectorToggleRemainsSingleAcrossPresentationChanges(initiallyPresented: Bool, width: Double) async throws {
    try await withWorkspace { model, _ in
        await model.createTask(title: "Inspect", vaultSession: model.vaultSession)
        model.isInspectorPresented = initiallyPresented
        let host = NSHostingController(rootView: WorkspaceView(model: model))
        let window = NSWindow(contentViewController: host)
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.setContentSize(NSSize(width: width, height: 700))
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
            try expectToolbarLayout(toolbar, window: window)
        }
    }
}

@MainActor
private func expectToolbarLayout(_ toolbar: NSToolbar, window: NSWindow) throws {
    let sidebar = try #require(toolbar.items.first { $0.label == "Toggle Sidebar" })
    let inspector = try #require(toolbar.items.first { $0.label.contains("Inspector") })
    let sidebarView = try #require(sidebar.view)
    let inspectorView = try #require(inspector.view)
    let leading = sidebarView.convert(sidebarView.bounds, to: nil)
    let trailing = inspectorView.convert(inspectorView.bounds, to: nil)
    #expect(leading.midX < window.frame.width / 2)
    #expect(trailing.midX > window.frame.width - 80)
    #expect(abs(leading.midY - trailing.midY) < 2)
    #expect(leading.width >= 36 && leading.height >= 36)
    #expect(trailing.width >= 36 && trailing.height >= 36)
    let commandItems = toolbar.items.filter { ["Search", "New Task", "View Options"].contains($0.label) }
    #expect(commandItems.count == 3)
    for item in commandItems {
        let view = try #require(item.view)
        let frame = view.convert(view.bounds, to: nil)
        #expect(frame.midX > leading.maxX && frame.midX < trailing.minX)
        #expect(abs(frame.midY - trailing.midY) < 2)
        #expect(frame.width >= 36 && frame.height >= 36)
    }
}
