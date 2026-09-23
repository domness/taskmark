import SwiftUI

/// Size the label inside the button so the whole target responds to clicks.
struct WorkspaceToolbarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .frame(minWidth: 36, minHeight: 36)
    }
}
