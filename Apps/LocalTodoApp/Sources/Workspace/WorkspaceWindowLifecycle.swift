import AppKit
import SwiftUI

struct WorkspaceWindowLifecycle: NSViewRepresentable {
    let model: WorkspaceModel
    let windows: WorkspaceWindows

    func makeCoordinator() -> WorkspaceWindowDelegate {
        WorkspaceWindowDelegate(model: model, windows: windows)
    }

    func makeNSView(context: Context) -> WorkspaceWindowAnchor {
        let view = WorkspaceWindowAnchor()
        view.windowDelegate = context.coordinator
        return view
    }

    func updateNSView(_ view: WorkspaceWindowAnchor, context _: Context) {
        view.connectWindow()
    }
}

final class WorkspaceWindowAnchor: NSView {
    weak var windowDelegate: WorkspaceWindowDelegate?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        connectWindow()
    }

    func connectWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            windowDelegate?.attach(to: window)
        }
    }
}

@MainActor
final class WorkspaceWindowDelegate: NSObject, NSWindowDelegate {
    let model: WorkspaceModel
    private let windows: WorkspaceWindows
    private let undoManager = UndoManager()
    /// Objective-C forwarding is nonisolated and NSWindowDelegate is not Sendable.
    /// Every read/write is main-actor confined; the forwarding entry points enforce that at runtime.
    nonisolated(unsafe) weak var sceneDelegate: (any NSWindowDelegate)?
    private var canCloseWorkspaceTab = false
    private var closeWorkspaceTab: (() -> Void)?

    init(model: WorkspaceModel, windows: WorkspaceWindows) {
        self.model = model
        self.windows = windows
    }

    func attach(to window: NSWindow?) {
        guard let window, window.delegate !== self else { return }
        sceneDelegate = window.delegate
        window.delegate = self
        model.setUndoManager(undoManager)
        window.tabbingMode = .disallowed
        windows.register(model)
        if window.isKeyWindow {
            windows.activate(model)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        windows.activate(model)
        sceneDelegate?.windowDidBecomeKey?(notification)
    }

    func windowWillReturnUndoManager(_: NSWindow) -> UndoManager? {
        undoManager
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if canCloseWorkspaceTab, WorkspaceCloseCommand.matches(NSApp.currentEvent) {
            closeWorkspaceTab?()
            return false
        }
        guard !model.isClosingWindow, !windows.isFlushingAll else { return false }
        guard !model.isLoading else {
            model.errorMessage = "Wait for the vault to finish opening before closing this window."
            return false
        }
        guard model.hasPendingDocumentChanges else {
            return sceneDelegate?.windowShouldClose?(sender) ?? true
        }
        model.isClosingWindow = true
        Task {
            let saved = await model.flushTaskChanges()
            model.isClosingWindow = false
            if saved {
                sender.performClose(nil)
            } else {
                model.errorMessage = "Finish capture and resolve pending changes before closing this window."
                sender.makeKeyAndOrderFront(nil)
            }
        }
        return false
    }

    func setWorkspaceTabCloseAction(canClose: Bool, action: @escaping () -> Void) {
        canCloseWorkspaceTab = canClose
        closeWorkspaceTab = action
    }

    func windowWillClose(_ notification: Notification) {
        sceneDelegate?.windowWillClose?(notification)
        windows.remove(model)
        model.releaseWindowResources()
    }

    /// Preserve SwiftUI's scene/restoration callbacks when interposing close validation.
    override nonisolated func responds(to selector: Selector!) -> Bool {
        MainActor.preconditionIsolated()
        if super.responds(to: selector) {
            return true
        }
        return sceneDelegate?.responds(to: selector) ?? false
    }

    override nonisolated func forwardingTarget(for _: Selector!) -> Any? {
        MainActor.preconditionIsolated()
        return sceneDelegate
    }
}

enum WorkspaceCloseCommand {
    static func matches(_ event: NSEvent?) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.charactersIgnoringModifiers?.lowercased() == "w" && modifiers == .command
    }
}

struct WorkspaceTabCloseBridge: NSViewRepresentable {
    let canCloseTab: Bool
    let onCloseTab: () -> Void

    func makeNSView(context _: Context) -> WorkspaceTabCloseAnchor {
        WorkspaceTabCloseAnchor()
    }

    func updateNSView(_ view: WorkspaceTabCloseAnchor, context _: Context) {
        view.connect(canClose: canCloseTab, action: onCloseTab)
    }
}

final class WorkspaceTabCloseAnchor: NSView {
    private var canClose = false
    private var action: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        publish()
    }

    func connect(canClose: Bool, action: @escaping () -> Void) {
        self.canClose = canClose
        self.action = action
        publish()
    }

    private func publish() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let action, let delegate = window?.delegate as? WorkspaceWindowDelegate else { return }
            delegate.setWorkspaceTabCloseAction(canClose: canClose, action: action)
        }
    }
}
