import AppKit
import SwiftUI

/// Observe double-clicks inside the title, leaving ordinary presses and drags to native List tracking.
struct TaskTitleDoubleClick: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context _: Context) -> TitleClickView {
        TitleClickView()
    }

    func updateNSView(_ view: TitleClickView, context _: Context) {
        view.action = action
    }

    static func dismantleNSView(_ view: TitleClickView, coordinator _: ()) {
        view.stopObserving()
    }
}

final class TitleClickView: NSView {
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
            // AppKit invokes local event monitors synchronously on the main thread.
            let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return handled ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard window != nil, event.clickCount == 2, event.window === window,
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
