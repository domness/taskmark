import AppKit
import Testing

@MainActor
func presentForNativeInput(_ window: NSWindow) async throws {
    // Hosted test processes can stay inactive even after activate(). Use the window's
    // own responder chain; OS key-window status is not a portable test precondition.
    window.makeKeyAndOrderFront(nil)
    window.contentView?.layoutSubtreeIfNeeded()
    try await waitForNativeUI("visible test window", in: window) {
        window.isVisible && window.contentView?.window === window
    }
}

/// Wait for an observed native transition, never retry the action that caused it.
@MainActor
func waitForNativeUI(
    _ transition: String,
    in window: NSWindow,
    diagnostics: () -> String = { "" },
    sourceLocation: SourceLocation = #_sourceLocation,
    until predicate: () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    var confirmations = 0
    // SwiftUI can insert/remove a native field before its queued focus updates finish.
    // Require the state to hold across event-loop turns before starting the next action.
    while ContinuousClock.now < deadline {
        window.contentView?.layoutSubtreeIfNeeded()
        confirmations = predicate() ? confirmations + 1 : 0
        if confirmations == 3 {
            return
        }
        try await Task.sleep(for: .milliseconds(25))
    }
    let responder = window.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
    let message = "Waiting for \(transition); visible=\(window.isVisible), key=\(window.isKeyWindow), "
        + "appActive=\(NSApp.isActive), responder=\(responder), "
        + "modal=\(NSApp.modalWindow != nil), sheets=\(window.sheets.count). \(diagnostics())"
        + "\n\((window as? NativeInputTestWindow)?.focusTrace.joined(separator: "\n") ?? "")"
    try #require(confirmations == 3, Comment(rawValue: message), sourceLocation: sourceLocation)
}

/// Keep a short focus trace in failing CI results, where the native window cannot be inspected live.
@MainActor
final class NativeInputTestWindow: NSWindow {
    private(set) var focusTrace: [String] = []

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        let name = responder.map { String(describing: type(of: $0)) } ?? "nil"
        let accepted = super.makeFirstResponder(responder)
        let stack = Thread.callStackSymbols.prefix(10).joined(separator: " | ")
        focusTrace.append("Focus → \(name), accepted=\(accepted): " + stack)
        if focusTrace.count > 8 {
            focusTrace.removeFirst()
        }
        return accepted
    }
}
