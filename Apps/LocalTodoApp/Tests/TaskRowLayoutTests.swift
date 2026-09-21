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
struct TaskListKeyboardTests {
    @Test func backspaceInFocusedListDeletesSelectedTask() async throws {
        try await withWorkspace { model, _ in
            model.route = .inbox
            await model.createTask(title: "Delete me", vaultSession: model.vaultSession)
            let path = try #require(model.selectedTaskPath)
            let draft = try #require(model.selectedTaskDraft)
            let window = makeWindow(model: model, draft: draft)
            let host = try #require(window.contentView)
            defer { window.close() }
            try await presentForNativeInput(window)
            try await waitForNativeUI("selected task row", in: window) {
                findTable(in: host)?.numberOfRows == 1
            }
            let event = try backspace(in: window)
            model.editTask(at: path)
            try await waitForNativeUI("inspector title editor focus", in: window) {
                (window.firstResponder as? NSTextView)?.string == "Delete me"
            }
            try await checkTextBackspace(in: host, draft: draft, event: event)
            #expect(model.snapshot?.tasks[path] != nil)
            // Finish the edit's persistence before testing a separate list-keyboard command.
            #expect(await model.flushTaskChanges())
            // Resolve the current native table after the editor/layout transition, then
            // select the row as a user would before sending the list command.
            let table = try #require(findTable(in: host))
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            #expect(window.makeFirstResponder(table))
            try await waitForNativeUI("list focus after ending title editing", in: window) {
                window.firstResponder === table && table.selectedRow == 0
            }
            #expect(model.selectedTaskPath == path)
            #expect(table.selectedRow == 0)
            try NSApp.postEvent(backspace(in: window), atStart: false)
            // Flushing drafts is not a barrier for a key event that has yet to dispatch its Task.
            try await waitForNativeUI(
                "Backspace deleting the selected task",
                in: window,
                diagnostics: { "error=\(model.errorMessage ?? "none")" },
                until: { model.snapshot?.tasks[path] == nil && model.deletingTaskPaths.isEmpty }
            )
            #expect(model.snapshot?.tasks[path] == nil)
        }
    }

    private func makeWindow(model: WorkspaceModel, draft: TaskDraft) -> NSWindow {
        let controller = NSHostingController(rootView: HStack {
            TaskListView(model: model)
            TaskInspectorView(model: model, draft: draft)
        })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        return window
    }

    private func backspace(in window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}", isARepeat: false, keyCode: 51
        ))
    }
}

@MainActor
private func checkTextBackspace(in view: NSView, draft: TaskDraft, event: NSEvent) async throws {
    let field = try #require(findTitleField(in: view))
    field.selectText(nil)
    let editor = try #require(field.currentEditor())
    editor.selectedRange = NSRange(location: editor.string.utf16.count, length: 0)
    NSApp.postEvent(event, atStart: false)
    let window = try #require(view.window)
    try await waitForNativeUI("text Backspace reaching the draft", in: window) {
        draft.title == "Delete m"
    }
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
