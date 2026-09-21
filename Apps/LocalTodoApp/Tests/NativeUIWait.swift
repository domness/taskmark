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
    while !predicate(), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(25))
    }
    let responder = window.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
    let message = "Waiting for \(transition); visible=\(window.isVisible), key=\(window.isKeyWindow), "
        + "appActive=\(NSApp.isActive), responder=\(responder), "
        + "modal=\(NSApp.modalWindow != nil), sheets=\(window.sheets.count). \(diagnostics())"
    try #require(predicate(), Comment(rawValue: message), sourceLocation: sourceLocation)
}
