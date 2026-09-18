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
        enableResizing()
    }

    func enableResizing() {
        // Wait until the Settings scene has applied its initial window style.
        DispatchQueue.main.async { [weak self] in
            self?.window?.styleMask.insert(.resizable)
        }
    }
}
