import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
@Test func taskListRemeasuresWhenScheduledDateAppearsAndDisappears() async throws {
    try await withWorkspace { model, _ in
        model.route = .inbox
        await model.createTask(title: "Resize me", vaultSession: model.vaultSession)
        let draft = try #require(model.selectedTaskDraft)
        let host = NSHostingView(rootView: TaskListView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        let table = try #require(findTable(in: host))
        let initial = table.rect(ofRow: 0).height
        draft.scheduled = "2026-09-18"
        #expect(await model.flushTaskChanges())
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        let scheduled = table.rect(ofRow: 0).height
        #expect(scheduled > initial)
        draft.scheduled = ""
        #expect(await model.flushTaskChanges())
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        #expect(table.rect(ofRow: 0).height == initial)
    }
}

@MainActor
@Test func backspaceInFocusedListDeletesSelectedTask() async throws {
    try await withWorkspace { model, _ in
        model.route = .inbox
        await model.createTask(title: "Delete me", vaultSession: model.vaultSession)
        let path = try #require(model.selectedTaskPath)
        let draft = try #require(model.selectedTaskDraft)
        let host = NSHostingView(rootView: HStack {
            TaskListView(model: model)
            TaskInspectorView(model: model, draft: draft)
        })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        let table = try #require(findTable(in: host))
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}", isARepeat: false, keyCode: 51
        ))
        model.editTask(at: path)
        try await Task.sleep(for: .milliseconds(100))
        try await checkTextBackspace(in: host, draft: draft, event: event)
        #expect(model.snapshot?.tasks[path] != nil)
        #expect(window.makeFirstResponder(table))
        #expect(model.selectedTaskPath == path)
        #expect(table.selectedRow == 0)
        NSApp.postEvent(event, atStart: false)
        try await Task.sleep(for: .milliseconds(100))
        #expect(await model.flushTaskChanges())
        #expect(model.snapshot?.tasks[path] == nil)
    }
}

@MainActor
private func checkTextBackspace(in view: NSView, draft: TaskDraft, event: NSEvent) async throws {
    let field = try #require(findTitleField(in: view))
    field.selectText(nil)
    let editor = try #require(field.currentEditor())
    editor.selectedRange = NSRange(location: editor.string.utf16.count, length: 0)
    NSApp.postEvent(event, atStart: false)
    try await Task.sleep(for: .milliseconds(100))
    #expect(draft.title == "Delete m")
}

@MainActor
private func findTitleField(in view: NSView) -> NSTextField? {
    if let field = view as? NSTextField, field.stringValue == "Delete me" {
        return field
    }
    return view.subviews.lazy.compactMap { findTitleField(in: $0) }.first
}

@MainActor
private func findTable(in view: NSView) -> NSTableView? {
    if let table = view as? NSTableView {
        return table
    }
    return view.subviews.lazy.compactMap { findTable(in: $0) }.first
}
