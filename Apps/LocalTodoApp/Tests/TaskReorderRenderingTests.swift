import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test(arguments: [false, true]) func taskRowsUseNativeSelectionWithoutOpeningInspector(custom: Bool) async throws {
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
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.selectedTaskDraft?.title == "First")
        #expect(!model.isInspectorPresented)
        try model.editTask(at: #require(model.selectedTaskPath))
        #expect(model.isInspectorPresented)
    }
}

@MainActor
private func reorderTable(in view: NSView) -> NSTableView? {
    if let table = view as? NSTableView {
        return table
    }
    return view.subviews.lazy.compactMap { reorderTable(in: $0) }.first
}
