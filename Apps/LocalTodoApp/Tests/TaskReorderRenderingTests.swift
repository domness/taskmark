import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test(arguments: [false, true]) func taskRowSingleClickOpensInspector(custom: Bool) async throws {
    try await withWorkspace { model, _ in
        model.route = .inbox
        for title in ["First", "Second"] {
            await model.createTask(title: title, vaultSession: model.vaultSession)
        }
        let host = NSHostingView(rootView: TaskListView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        model.setTaskListSort(custom ? .custom : .automatic(.title))
        model.selectTask(nil)
        try await Task.sleep(for: .milliseconds(150))
        host.layoutSubtreeIfNeeded()
        let table = try #require(reorderTable(in: host))
        #expect(table.numberOfRows == 2)
        #expect(table.selectedRowIndexes.isEmpty)
        model.isInspectorPresented = false
        try clickTaskTitle(in: host, window: window)
        try await waitForNativeUI("single-click task details", in: window) {
            model.selectedTaskDraft?.title == "First" && model.isInspectorPresented
        }
        #expect(model.selectedTaskDraft?.title == "First")
        #expect(model.isInspectorPresented)
        #expect(model.titleEditingPath == nil)
    }
}

@MainActor
private func clickTaskTitle(in view: NSView, window: NSWindow) throws {
    let target = try #require(titleClickTarget(in: view))
    let point = target.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), to: nil)
    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
        let event = try #require(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1
        ))
        NSApp.postEvent(event, atStart: false)
    }
}

@MainActor
private func titleClickTarget(in view: NSView) -> TitleClickView? {
    if let target = view as? TitleClickView, !target.visibleRect.isEmpty {
        return target
    }
    return view.subviews.lazy.compactMap { titleClickTarget(in: $0) }.first
}

@MainActor
private func reorderTable(in view: NSView) -> NSTableView? {
    if let table = view as? NSTableView {
        return table
    }
    return view.subviews.lazy.compactMap { reorderTable(in: $0) }.first
}
