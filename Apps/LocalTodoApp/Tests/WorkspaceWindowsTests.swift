import AppKit
@testable import LocalTodoApp
import LocalTodoMarkdown
import SwiftUI
import Testing

@MainActor
@Test func vaultWindowsKeepDraftsSelectionsAndUndoIndependent() async throws {
    try await withTwoVaultWindows { windows, first, second, _, _ in
        await first.createTask(title: "Shared path", vaultSession: first.vaultSession)
        await second.createTask(title: "Shared path", vaultSession: second.vaultSession)
        let firstDraft = try #require(first.selectedTaskDraft)
        let secondDraft = try #require(second.selectedTaskDraft)
        #expect(firstDraft.path == secondDraft.path)
        #expect(firstDraft.vaultSession != secondDraft.vaultSession)
        let undo = try #require(first.undoManager)
        #expect(undo !== second.undoManager)
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        first.changeDraft(firstDraft, keyPath: \.notes, to: "First notes", actionName: "Edit Notes")
        undo.endUndoGrouping()
        secondDraft.notes = "Second notes"
        #expect(await windows.flushAll())
        first.performUndo()
        #expect(await first.flushTaskChanges())
        #expect(firstDraft.notes.isEmpty)
        #expect(secondDraft.notes == "Second notes")
        first.route = .upcoming
        #expect(second.selectedTaskPath == secondDraft.path)
        #expect(second.route != .upcoming)
        first.preferences.theme = .forest
        #expect(first.preferences.theme == .forest)
        #expect(second.preferences.theme == .standard)
        #expect(await windows.flushAll())
    }
}

@MainActor
@Test func windowDelegatesSelectTheSettingsVault() async throws {
    try await withTwoVaultWindows { windows, first, second, firstWindow, secondWindow in
        for (model, window) in [(first, firstWindow), (second, secondWindow), (first, firstWindow)] {
            // Exercise focus routing without forwarding a synthetic key notification into SwiftUI's scene delegate.
            let delegate = WorkspaceWindowDelegate(model: model, windows: windows)
            delegate.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: window))
            #expect(windows.settingsWorkspace === model)
        }
    }
}

@MainActor
@Test func closingOneVaultFlushesItsDraftWithoutClosingTheOther() async throws {
    try await withTwoVaultWindows { windows, first, second, firstWindow, secondWindow in
        await first.createTask(title: "Save on close", vaultSession: first.vaultSession)
        let draft = try #require(first.selectedTaskDraft)
        let root = try #require(first.rootURL)
        draft.notes = "Must survive closing"
        firstWindow.performClose(nil)
        for _ in 0 ..< 40 where firstWindow.isVisible {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!firstWindow.isVisible)
        #expect(secondWindow.isVisible)
        #expect(windows.workspaces.count == 1)
        #expect(first.rootURL == nil)
        #expect(second.rootURL != nil)
        #expect(try await VaultStore(root: root).snapshot().tasks[draft.path]?.value.body == "Must survive closing")
    }
}

@MainActor
@Test func incompleteCaptureBlocksWindowCloseAndApplicationQuit() async throws {
    try await withTwoVaultWindows { windows, first, second, firstWindow, _ in
        await second.createTask(title: "Background edit", vaultSession: second.vaultSession)
        let draft = try #require(second.selectedTaskDraft)
        draft.notes = "Still save the other vault"
        first.quickCaptureTitle = "Unsubmitted capture"
        firstWindow.performClose(nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(firstWindow.isVisible)
        #expect(first.quickCaptureTitle == "Unsubmitted capture")
        #expect(await !(windows.flushAll()))
        #expect(!draft.isDirty)
        #expect(first.errorMessage != nil)
        first.quickCaptureTitle = ""
        first.errorMessage = nil
        #expect(await windows.flushAll())
    }
}

@MainActor
@Test func onlyInitialWindowRestoresTheRecentVault() async throws {
    try await withWorkspace { previous, root in
        let windows = WorkspaceWindows(preferences: previous.preferences)
        let suite = "InitialWindowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try VaultBookmarkStore(defaults: defaults).save(root)
        let first = makeWindowModel(defaults: defaults, preferences: previous.preferences)
        let second = makeWindowModel(defaults: defaults, preferences: previous.preferences)
        defer {
            first.releaseWindowResources()
            second.releaseWindowResources()
        }
        await windows.start(first)
        await windows.start(second)
        await windows.start(first)
        #expect(first.rootURL?.standardizedFileURL.path == root.standardizedFileURL.path)
        #expect(second.rootURL == nil)
        #expect(windows.workspaces.count == 2)
    }
}

@MainActor
@Test func invalidDraftInBackgroundVaultPreventsQuit() async throws {
    try await withTwoVaultWindows { windows, first, second, _, _ in
        await first.createTask(title: "First", vaultSession: first.vaultSession)
        await second.createTask(title: "Second", vaultSession: second.vaultSession)
        let firstDraft = try #require(first.selectedTaskDraft)
        let secondDraft = try #require(second.selectedTaskDraft)
        firstDraft.notes = "Valid pending changes"
        secondDraft.title = ""
        #expect(await !(windows.flushAll()))
        #expect(!firstDraft.isDirty)
        #expect(secondDraft.isDirty)
        #expect(second.snapshot?.tasks[secondDraft.path]?.value.title == "Second")
        secondDraft.title = "Corrected"
        second.errorMessage = nil
        #expect(await windows.flushAll())
    }
}

@MainActor
private func withTwoVaultWindows(
    _ operation: (WorkspaceWindows, WorkspaceModel, WorkspaceModel, NSWindow, NSWindow) async throws -> Void
) async throws {
    let suite = "WorkspaceWindowsTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
    defer {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
    let preferences = AppPreferences()
    let windows = WorkspaceWindows(preferences: preferences)
    let first = makeWindowModel(defaults: defaults, preferences: preferences)
    let second = makeWindowModel(defaults: defaults, preferences: preferences)
    await first.createVault(at: root.appendingPathComponent("First"))
    await second.createVault(at: root.appendingPathComponent("Second"))
    let firstWindow = makeVaultWindow(first, windows: windows)
    let secondWindow = makeVaultWindow(second, windows: windows)
    defer {
        firstWindow.close()
        secondWindow.close()
    }
    try await Task.sleep(for: .milliseconds(150))
    #expect(firstWindow.delegate is WorkspaceWindowDelegate)
    #expect(secondWindow.delegate is WorkspaceWindowDelegate)
    #expect(windows.workspaces.count == 2)
    try await operation(windows, first, second, firstWindow, secondWindow)
}

@MainActor
private func makeWindowModel(defaults: UserDefaults, preferences: AppPreferences) -> WorkspaceModel {
    WorkspaceModel(
        bookmarks: VaultBookmarkStore(defaults: defaults),
        preferences: preferences
    )
}

@MainActor
private func makeVaultWindow(_ model: WorkspaceModel, windows: WorkspaceWindows) -> NSWindow {
    let window = NSWindow(contentViewController: NSHostingController(
        rootView: WorkspaceWindowRoot(windows: windows, model: model)
    ))
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 1200, height: 700))
    window.makeKeyAndOrderFront(nil)
    return window
}
