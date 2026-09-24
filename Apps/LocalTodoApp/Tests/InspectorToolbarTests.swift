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
            // The system sidebar control can live outside NSToolbar on newer macOS.
            // Never add a second, app-authored toggle beside it.
            #expect(!toolbar.items.contains { $0.itemIdentifier.rawValue == "taskmark.sidebar-toggle" })
            #expect(toolbar.items.filter { $0.itemIdentifier == .toggleSidebar }.count <= 1)
            #expect(toggles.count == 1, Comment(rawValue: labels))
            #expect(toggles.first?.label == (presented ? "Hide Inspector" : "Show Inspector"))
            try expectToolbarLayout(toolbar, window: window)
        }
    }
}

@MainActor
private func expectToolbarLayout(_ toolbar: NSToolbar, window: NSWindow) throws {
    let inspector = try #require(toolbar.items.first { $0.label.contains("Inspector") })
    let inspectorView = try #require(inspector.view)
    let trailing = inspectorView.convert(inspectorView.bounds, to: nil)
    #expect(trailing.midX > window.frame.width - 80)
    #expect(trailing.width >= 20 && trailing.height >= 20)
    #expect(trailing.height < 36, "Use the compact native toolbar size: \(trailing)")
    let commandItems = toolbar.items.filter { ["Search", "New Task", "View Options"].contains($0.label) }
    #expect(commandItems.count == 3)
    for item in commandItems {
        let view = try #require(item.view)
        let frame = view.convert(view.bounds, to: nil)
        #expect(frame.midX > window.frame.width / 2 && frame.midX < trailing.minX)
        #expect(abs(frame.midY - trailing.midY) < 2)
        #expect(frame.width >= 20, "\(item.label): \(frame)")
        #expect(abs(frame.height - trailing.height) < 2, "\(item.label): \(frame)")
    }
}
