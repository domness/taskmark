import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test(arguments: [false, true], [840.0, 1120.0, 1600.0])
func inspectorToggleRemainsSingleAcrossPresentationChanges(initiallyPresented: Bool, width: Double) async throws {
    try await withToolbarWindow(initiallyPresented: initiallyPresented, width: width) { model, window in
        for presented in [initiallyPresented, !initiallyPresented, initiallyPresented, !initiallyPresented] {
            // Inspector animations can stall in an occluded/locked test session. Test final
            // native geometry without animation; physical transitions need visual acceptance.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { model.isInspectorPresented = presented }
            try await waitForInspector(presented, in: window)
            let toolbar = try #require(window.toolbar)
            try await settleToolbar(toolbar)
            try expectToolbarLayout(toolbar, window: window, inspectorPresented: presented)
        }
    }
}

@MainActor
@Test func toolbarActionsFollowInspectorAndWindowResizing() async throws {
    try await withToolbarWindow(initiallyPresented: true, width: 1600) { model, window in
        try await waitForInspector(true, in: window)
        let toolbar = try #require(window.toolbar)
        let root = try #require(window.contentView)
        let panel = try #require(inspectorPanel(in: root, window: window))
        let split = try #require(splitViews(in: root).first { $0.arrangedSubviews.last === panel })
        for width in [480.0, 280.0, 400.0, 340.0] {
            split.setPosition(split.bounds.width - width - split.dividerThickness, ofDividerAt: 0)
            try await settleToolbar(toolbar)
            #expect(abs(panel.frame.width - width) < 2, "Inspector must actually resize")
            try expectToolbarLayout(toolbar, window: window, inspectorPresented: true)
        }
        for width in [1120.0, 840.0, 1600.0] {
            window.setContentSize(NSSize(width: width, height: 700))
            try await settleToolbar(toolbar)
            try expectToolbarLayout(toolbar, window: window, inspectorPresented: true)
        }
        model.route = .issues
        try await settleToolbar(toolbar)
        try expectToolbarLayout(toolbar, window: window, inspectorPresented: true, showsCommands: false)
        model.route = .inbox
        try await settleToolbar(toolbar)
        try expectToolbarLayout(toolbar, window: window, inspectorPresented: true)
    }
}

@MainActor
@Test func workspaceToolbarControlsAreLargerThanCompactNativeControls() async throws {
    try await withToolbarWindow(initiallyPresented: false, width: 1120) { _, window in
        try await waitForInspector(false, in: window)
        let toolbar = try #require(window.toolbar)
        try await settleToolbar(toolbar)
        #expect(window.toolbarStyle == .unified)
        let fullSize = try toolbarControlSizes(toolbar)
        window.toolbarStyle = .unifiedCompact
        defer { window.toolbarStyle = .unified }
        try await settleToolbar(toolbar)
        let compactSize = try toolbarControlSizes(toolbar)
        for (label, size) in fullSize {
            let compact = try #require(compactSize[label])
            #expect(size.height > compact.height, "\(label): full=\(size), compact=\(compact)")
        }
    }
}

@MainActor
private func toolbarControlSizes(_ toolbar: NSToolbar) throws -> [String: CGSize] {
    var sizes: [String: CGSize] = [:]
    for label in ["Search", "New Task", "View Options", "Show Inspector"] {
        let view = try #require(toolbar.items.first { $0.label == label }?.view)
        sizes[label] = view.bounds.size
    }
    return sizes
}

@MainActor
private func withToolbarWindow(
    initiallyPresented: Bool, width: Double,
    _ operation: @MainActor (WorkspaceModel, NSWindow) async throws -> Void
) async throws {
    try await withWorkspace { fixture, root in
        await fixture.createTask(title: "Inspect", vaultSession: fixture.vaultSession)
        // Use the production scene so toolbar style and split layout cannot diverge from the app.
        let window = try await openVaultScene()
        defer { window.close() }
        let model = try #require((window.delegate as? WorkspaceWindowDelegate)?.model)
        defer { model.releaseWindowResources() }
        model.isInspectorPresented = initiallyPresented
        #expect(try await model.openVault(root))
        window.setContentSize(NSSize(width: width, height: 700))
        window.makeKeyAndOrderFront(nil)
        try await operation(model, window)
    }
}

@MainActor
private func waitForInspector(_ presented: Bool, in window: NSWindow) async throws {
    let content = try #require(window.contentView)
    let expectedLabel = presented ? "Hide Inspector" : "Show Inspector"
    for _ in 0 ..< 60 {
        try await Task.sleep(for: .milliseconds(50))
        window.display()
        let toggles = window.toolbar?.items.filter { $0.label.contains("Inspector") } ?? []
        let panelMatches = (inspectorPanel(in: content, window: window) != nil) == presented
        if toggles.count == 1, toggles.first?.label == expectedLabel, panelMatches {
            return
        }
    }
    let panels = splitViews(in: content).flatMap(\.arrangedSubviews).map {
        $0.convert($0.bounds, to: nil)
    }
    Issue.record("Inspector presentation did not settle: open=\(presented), panels=\(panels)")
}

@MainActor
private func settleToolbar(_ toolbar: NSToolbar) async throws {
    var previous: [CGRect] = []
    var confirmations = 0
    for _ in 0 ..< 60 {
        try await Task.sleep(for: .milliseconds(50))
        let frames = toolbar.items.compactMap { item in
            item.view.map { $0.convert($0.bounds, to: nil) }
        }
        confirmations = frames == previous ? confirmations + 1 : 0
        if confirmations == 5 {
            return
        }
        previous = frames
    }
    #expect(confirmations == 5, "Toolbar geometry did not settle")
}

@MainActor
private func expectToolbarLayout(
    _ toolbar: NSToolbar, window: NSWindow, inspectorPresented: Bool, showsCommands: Bool = true
) throws {
    let toggles = toolbar.items.filter { $0.label.contains("Inspector") }
    #expect(toggles.count == 1)
    #expect(toggles.first?.label == (inspectorPresented ? "Hide Inspector" : "Show Inspector"))
    // The system sidebar control can live outside NSToolbar on newer macOS.
    #expect(!toolbar.items.contains { $0.itemIdentifier.rawValue == "taskmark.sidebar-toggle" })
    #expect(toolbar.items.filter { $0.itemIdentifier == .toggleSidebar }.count <= 1)
    let inspectorView = try #require(toggles.first?.view)
    let trailing = inspectorView.convert(inspectorView.bounds, to: nil)
    #expect(trailing.midX > window.frame.width - 80)
    #expect(window.toolbarStyle == .unified)
    // macOS 15 uses 28-point native controls; newer systems use larger dimensions.
    // The separate compact comparison verifies enlargement on the running OS.
    #expect(trailing.width >= 28 && trailing.height >= 28, "Use full-sized toolbar controls: \(trailing)")
    let commandBoundary = inspectorPresented ? try inspectorLeadingEdge(in: window) : trailing.minX
    let commandItems = toolbar.items.filter { ["Search", "New Task", "View Options"].contains($0.label) }
    #expect(commandItems.count == (showsCommands ? 3 : 0))
    for item in commandItems {
        let view = try #require(item.view)
        let frame = view.convert(view.bounds, to: nil)
        #expect(frame.maxX <= commandBoundary, "\(item.label) must stay above the center panel: \(frame)")
        #expect(abs(frame.midY - trailing.midY) < 2)
        #expect(frame.width >= 28, "\(item.label): \(frame)")
        #expect(abs(frame.height - trailing.height) < 2, "\(item.label): \(frame)")
    }
    if showsCommands {
        let options = try #require(commandItems.last?.view)
        let frame = options.convert(options.bounds, to: nil)
        #expect(commandBoundary - frame.maxX < 40, "Actions must hug the center panel's trailing edge: \(frame)")
    }
}

@MainActor
private func inspectorLeadingEdge(in window: NSWindow) throws -> CGFloat {
    let root = try #require(window.contentView)
    let panel = try #require(inspectorPanel(in: root, window: window))
    return panel.convert(panel.bounds, to: nil).minX
}

@MainActor
private func inspectorPanel(in root: NSView, window: NSWindow) -> NSView? {
    splitViews(in: root).compactMap { split -> NSView? in
        guard let last = split.arrangedSubviews.last,
              !last.isHiddenOrHasHiddenAncestor, !split.isSubviewCollapsed(last),
              (279 ... 481).contains(last.frame.width),
              abs(last.convert(last.bounds, to: nil).maxX - window.frame.width) < 2
        else { return nil }
        return last
    }.first
}

@MainActor
private func splitViews(in view: NSView) -> [NSSplitView] {
    let current = (view as? NSSplitView).map { [$0] } ?? []
    return current + view.subviews.flatMap { splitViews(in: $0) }
}
