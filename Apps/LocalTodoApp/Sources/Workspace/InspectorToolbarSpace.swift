import AppKit
import SwiftUI

/// A fixed native toolbar space; SwiftUI Spacer becomes a flexible NSToolbar item.
struct InspectorToolbarSpace: NSViewRepresentable {
    let width: CGFloat

    func makeNSView(context _: Context) -> SpaceView {
        SpaceView(width: width)
    }

    func updateNSView(_ view: SpaceView, context _: Context) {
        view.width = width
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_: ProposedViewSize, nsView _: SpaceView, context _: Context) -> CGSize? {
        CGSize(width: width, height: 1)
    }

    final class SpaceView: NSView {
        var width: CGFloat

        init(width: CGFloat) {
            self.width = width
            super.init(frame: .zero)
            setAccessibilityElement(false)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: width, height: 1)
        }
    }
}
