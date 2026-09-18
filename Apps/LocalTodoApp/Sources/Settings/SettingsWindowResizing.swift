import AppKit
import SwiftUI

/// Settings scenes can omit the native resize style even when SwiftUI's size limits permit resizing.
struct SettingsWindowResizing: NSViewRepresentable {
    func makeNSView(context _: Context) -> SettingsWindowAnchor {
        SettingsWindowAnchor()
    }

    func updateNSView(_ view: SettingsWindowAnchor, context _: Context) {
        view.enableResizing()
    }
}

final class SettingsWindowAnchor: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didUpdateNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowUpdated), name: NSWindow.didUpdateNotification, object: window
            )
        }
        enableResizing()
    }

    @objc private func windowUpdated(_: Notification) {
        enableResizing()
    }

    func enableResizing() {
        // Wait until the Settings scene has applied its initial window style.
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window, !window.styleMask.contains(.resizable) else { return }
            window.styleMask.insert(.resizable)
        }
    }
}
