import SwiftUI

/// A quiet label column with a flexible, trailing-aligned value column.
struct InspectorPropertyRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .themeFont(.callout)
                .foregroundStyle(.secondary)
                .fixedSize()
            content
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 30)
        .padding(.vertical, 2)
    }
}

struct InspectorPropertySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .themeFont(.caption, weight: .semibold)
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .menuStyle(.borderlessButton)
            .tint(.primary)
        }
    }
}
