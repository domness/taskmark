import AppKit
@testable import LocalTodoApp
import SwiftUI
import Testing

@MainActor
struct InlineTaskTitleTests {
    @Test(arguments: [false, true])
    func enterAndFocusLossSaveTitle(customOrder: Bool) async throws {
        try await withWorkspace { model, _ in
            model.route = .inbox
            await model.createTask(title: "Original **title**", vaultSession: model.vaultSession)
            let draft = try #require(model.selectedTaskDraft)
            if customOrder {
                model.setTaskListSort(.custom)
            }
            let host = NSHostingView(rootView: TaskListView(model: model))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled], backing: .buffered, defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            defer { window.close() }

            try await doubleClickTitle(in: host, window: window)
            let field = try await titleField(in: host)
            #expect(field.stringValue == "Original **title**")
            try replaceTitle(in: field, with: "Renamed **task**")
            #expect(draft.title == "Renamed **task**")
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: "\r",
                charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
            ))
            NSApp.postEvent(event, atStart: false)
            try await waitForSave(model, draft: draft, title: "Renamed **task**")
            for _ in 0 ..< 40 where findField(in: host) != nil {
                try await Task.sleep(for: .milliseconds(50))
            }

            model.beginInlineTitleEditing(at: draft.path)
            let secondField = try await titleField(in: host)
            try replaceTitle(in: secondField, with: "Click away")
            #expect(window.makeFirstResponder(nil))
            try await waitForSave(model, draft: draft, title: "Click away")
            try await checkOutsideClick(model, draft: draft, host: host, window: window)
        }
    }

    @Test func invalidTitleRetainsDraftAndOriginalFile() async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "Keep me", vaultSession: model.vaultSession)
            let draft = try #require(model.selectedTaskDraft)
            model.beginInlineTitleEditing(at: draft.path)
            model.changeDraft(draft, keyPath: \.title, to: "   ", actionName: "Edit Title")
            model.finishInlineTitleEditing(draft)
            #expect(model.errorMessage != nil)
            #expect(model.isInspectorPresented)
            #expect(draft.title == "   ")
            #expect(await model.flushTaskChanges() == false)
            #expect(model.snapshot?.tasks[draft.path]?.value.title == "Keep me")
        }
    }

    private func replaceTitle(in field: NSTextField, with title: String) throws {
        field.selectText(nil)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText(title, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        editor.didChangeText()
    }

    private func checkOutsideClick(
        _ model: WorkspaceModel, draft: TaskDraft, host: NSView, window: NSWindow
    ) async throws {
        for _ in 0 ..< 40 where findField(in: host) != nil {
            try await Task.sleep(for: .milliseconds(50))
        }
        model.beginInlineTitleEditing(at: draft.path)
        let field = try await titleField(in: host)
        try replaceTitle(in: field, with: "Outside click")
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: NSPoint(x: 20, y: 390), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
            ))
            NSApp.postEvent(event, atStart: false)
        }
        try await waitForSave(model, draft: draft, title: "Outside click")
    }

    private func doubleClickTitle(in host: NSView, window: NSWindow) async throws {
        for _ in 0 ..< 40 where findTitleTarget(in: host)?.visibleRect.isEmpty != false {
            try await Task.sleep(for: .milliseconds(50))
        }
        let title = try #require(findTitleTarget(in: host))
        host.layoutSubtreeIfNeeded()
        let bounds = title.visibleRect
        let point = title.convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
        for count in 1 ... 2 {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try #require(NSEvent.mouseEvent(
                    with: type, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil,
                    eventNumber: count, clickCount: count, pressure: 1
                ))
                NSApp.postEvent(event, atStart: false)
            }
        }
    }

    private func findTitleTarget(in view: NSView) -> TitleClickView? {
        if let title = view as? TitleClickView {
            return title
        }
        return view.subviews.lazy.compactMap { findTitleTarget(in: $0) }.first
    }

    private func titleField(in view: NSView) async throws -> NSTextField {
        for _ in 0 ..< 40 {
            if let field = findField(in: view), field.currentEditor() != nil {
                return field
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        return try #require(findField(in: view))
    }

    private func findField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.placeholderString == "Task title" {
            return field
        }
        return view.subviews.lazy.compactMap { findField(in: $0) }.first
    }

    private func waitForSave(_ model: WorkspaceModel, draft: TaskDraft, title: String) async throws {
        for _ in 0 ..< 40 {
            if model.inlineTitleEditingPath == nil, !draft.isDirty {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(model.inlineTitleEditingPath == nil, "Editor should close after saving \(title)")
        #expect(!draft.isDirty)
        #expect(model.snapshot?.tasks[draft.path]?.value.title == title)
    }
}
