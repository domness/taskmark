import AppKit
import SwiftUI

/// Plain Form backgrounds and macOS buttons do not necessarily take first responder.
/// End source editing on clicks outside the field, without consuming the destination's event.
struct MarkdownEditingBoundary: NSViewRepresentable {
    let onOutsideClick: () -> Void

    func makeNSView(context _: Context) -> MarkdownEditingBoundaryView {
        let view = MarkdownEditingBoundaryView()
        view.onOutsideClick = onOutsideClick
        return view
    }

    func updateNSView(_ view: MarkdownEditingBoundaryView, context _: Context) {
        view.onOutsideClick = onOutsideClick
    }

    static func dismantleNSView(_ view: MarkdownEditingBoundaryView, coordinator _: ()) {
        view.stopMonitoring()
    }
}

final class MarkdownEditingBoundaryView: NSView {
    var onOutsideClick: (() -> Void)?
    private var monitor: Any?

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleMouseDown(event)
            }
            return event
        }
    }

    func handleMouseDown(_ event: NSEvent) {
        guard let window, event.window === window,
              !bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onOutsideClick?()
    }

    func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
