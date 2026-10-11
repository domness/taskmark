import AppKit
import SwiftUI

/// A fixed native toolbar space; SwiftUI Spacer becomes a flexible NSToolbar item.
struct InspectorToolbarSpace: NSViewRepresentable {
    let width: CGFloat

    func makeNSView(context _: Context) -> SpaceView {
        SpaceView(width: width)
    }

    func updateNSView(_ view: SpaceView, context _: Context) {
        view.update(width: width)
    }

    func sizeThatFits(_: ProposedViewSize, nsView _: SpaceView, context _: Context) -> CGSize? {
        CGSize(width: max(1, width), height: 1)
    }

    final class SpaceView: NSView {
        private(set) var width: CGFloat

        init(width: CGFloat) {
            self.width = width
            super.init(frame: .zero)
            setAccessibilityElement(false)
            isHidden = width == 0
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        @discardableResult
        func update(width: CGFloat) -> Bool {
            guard width != self.width else { return false }
            self.width = width
            isHidden = width == 0
            invalidateIntrinsicContentSize()
            return true
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: max(1, width), height: 1)
        }
    }
}
