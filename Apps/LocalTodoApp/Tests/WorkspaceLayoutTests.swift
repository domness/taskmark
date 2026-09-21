import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
struct WorkspaceLayoutTests {
    @Test(arguments: [840.0, 1088.0, 1120.0])
    func openingVaultKeepsSplitPanelsInsideWindow(width: Double) async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "A task in the new window", vaultSession: model.vaultSession)
            let path = model.selectedTaskPath
            model.route = .inbox
            model.selectedTaskPath = nil
            let snapshot = model.snapshot
            model.snapshot = nil
            let host = NSHostingController(rootView: WorkspaceView(model: model))
            let window = NSWindow(contentViewController: host)
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: width, height: 680))
            window.orderFront(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(100))
            model.snapshot = snapshot
            for presented in [true, false, true] {
                model.isInspectorPresented = presented
                try await Task.sleep(for: .milliseconds(500))
                checkPanels(in: host.view)
            }
            model.selectedTaskPath = path
            try await Task.sleep(for: .milliseconds(500))
            checkPanels(in: host.view)
        }
    }
}

@MainActor
private func checkPanels(in root: NSView) {
    root.layoutSubtreeIfNeeded()
    let splits = splitViews(in: root)
    #expect(!splits.isEmpty)
    for split in splits {
        for panel in split.arrangedSubviews where !panel.isHidden {
            let rect = panel.convert(panel.bounds, to: root)
            #expect(rect.minX >= -1, "Panel starts outside window: \(rect)")
            #expect(rect.maxX <= root.bounds.width + 1, "Panel ends outside window: \(rect)")
        }
    }
}

@MainActor
private func splitViews(in view: NSView) -> [NSSplitView] {
    let current = (view as? NSSplitView).map { [$0] } ?? []
    return current + view.subviews.flatMap { splitViews(in: $0) }
}
