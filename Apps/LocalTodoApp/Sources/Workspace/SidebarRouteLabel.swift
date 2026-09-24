import SwiftUI

struct SidebarRouteLabel: View {
    let model: WorkspaceModel
    let route: WorkspaceRoute
    let title: String
    let systemImage: String

    var body: some View {
        let count = model.sidebarTaskCount(for: route)
        HStack {
            Label(title, systemImage: systemImage)
            Spacer(minLength: 8)
            if let count {
                Text(count, format: .number)
                    .themeFont(.caption, weight: .medium)
                    .monospacedDigit()
                    .foregroundStyle(model.route == route ? Color.white : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background {
                        Capsule().fill(model.route == route ? Color.white.opacity(0.21) : Color.secondary.opacity(0.12))
                    }
                    .fixedSize()
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(count.map { "\($0) tasks" } ?? "")
    }
}
