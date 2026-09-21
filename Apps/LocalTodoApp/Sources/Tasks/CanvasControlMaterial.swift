import SwiftUI

/// Materials belong to commands, never to the task reading surface.
struct CanvasControlMaterial: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
            if #available(macOS 26, *), !reduceTransparency, contrast != .increased {
                content.glassEffect(.regular, in: .capsule)
            } else {
                content
            }
        #else
            content
        #endif
    }
}
