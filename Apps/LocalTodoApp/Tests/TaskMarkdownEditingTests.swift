import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
struct TaskMarkdownEditingTests {
    @Test(arguments: [TaskMarkdownField.Kind.title, .notes])
    func editingUsesSourceAndFocusLossRestoresRendering(kind: TaskMarkdownField.Kind) async throws {
        let state = MarkdownFieldTestState()
        let host = NSHostingView(rootView: VStack {
            TaskMarkdownField(
                text: Binding(get: { state.text }, set: { state.text = $0 }),
                kind: kind,
                isEditing: Binding(get: { state.isEditing }, set: { state.isEditing = $0 })
            )
            .frame(width: 360, height: 180)
            TextField("Other field", text: .constant("Other"))
        }.padding())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        #expect(!state.isEditing)
        state.isEditing = true
        try await Task.sleep(for: .milliseconds(150))
        #expect(state.isEditing)
        let editor = try #require(window.firstResponder as? NSTextView)
        #expect(editor.string == state.text)
        editor.selectAll(nil)
        editor.insertText("Updated **Markdown**", replacementRange: editor.selectedRange())
        try await Task.sleep(for: .milliseconds(100))
        #expect(state.text == "Updated **Markdown**")
        let other = try #require(textField(in: host, value: "Other"))
        other.selectText(nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!state.isEditing)
        #expect(state.text == "Updated **Markdown**")
        try await checkOutsideClick(state: state, window: window, host: host)
    }

    private func checkOutsideClick(state: MarkdownFieldTestState, window: NSWindow, host: NSView) async throws {
        state.isEditing = true
        try await Task.sleep(for: .milliseconds(100))
        let boundary = try #require(descendant(in: host, as: MarkdownEditingBoundaryView.self))
        try boundary.handleMouseDown(mouseDown(window, at: NSPoint(x: 1, y: 1)))
        try await Task.sleep(for: .milliseconds(100))
        #expect(!state.isEditing)
        #expect(state.text == "Updated **Markdown**")
    }

    @Test func clicksInsideEditorOrInAnotherWindowDoNotEndEditing() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let otherWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        otherWindow.isReleasedWhenClosed = false
        defer {
            window.close()
            otherWindow.close()
        }
        let boundary = MarkdownEditingBoundaryView(frame: NSRect(x: 20, y: 20, width: 100, height: 100))
        var ended = false
        boundary.onOutsideClick = { ended = true }
        window.contentView?.addSubview(boundary)
        defer { boundary.stopMonitoring() }
        try boundary.handleMouseDown(mouseDown(window, at: NSPoint(x: 50, y: 50)))
        #expect(!ended)
        try boundary.handleMouseDown(mouseDown(otherWindow, at: NSPoint(x: 1, y: 1)))
        #expect(!ended)
        try boundary.handleMouseDown(mouseDown(window, at: NSPoint(x: 1, y: 1)))
        #expect(ended)
    }

    private func mouseDown(_ window: NSWindow, at point: NSPoint) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }
}

@MainActor @Observable
private final class MarkdownFieldTestState {
    var text = "Original **Markdown**"
    var isEditing = false
}

@MainActor
private func descendant<T: NSView>(in view: NSView, as type: T.Type) -> T? {
    (view as? T) ?? view.subviews.lazy.compactMap { descendant(in: $0, as: type) }.first
}

@MainActor
private func textField(in view: NSView, value: String) -> NSTextField? {
    if let field = view as? NSTextField, field.stringValue == value {
        return field
    }
    return view.subviews.lazy.compactMap { textField(in: $0, value: value) }.first
}
