import AppKit
import SwiftUI

struct CommandClickView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context _: Context) -> CommandClickTrackingView {
        CommandClickTrackingView()
    }

    func updateNSView(_ view: CommandClickTrackingView, context _: Context) {
        view.action = action
    }

    static func dismantleNSView(_ view: CommandClickTrackingView, coordinator _: ()) {
        view.stopObserving()
    }
}

enum CommandClickGesture {
    static func matches(clickCount: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
        clickCount == 1 && modifiers.intersection(.deviceIndependentFlagsMask).contains(.command)
    }
}

final class CommandClickTrackingView: NSView {
    var action: (() -> Void)?
    private var monitor: Any?

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopObserving()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return handled ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard window != nil, event.window === window,
              CommandClickGesture.matches(clickCount: event.clickCount, modifiers: event.modifierFlags),
              !isHiddenOrHasHiddenAncestor,
              visibleRect.contains(convert(event.locationInWindow, from: nil))
        else { return false }
        action?()
        return true
    }

    func stopObserving() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
