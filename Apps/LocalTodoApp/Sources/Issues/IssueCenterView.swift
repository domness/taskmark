import SwiftUI

struct IssueCenterView: View {
    let model: WorkspaceModel

    var body: some View {
        Group {
            if let diagnostics = model.snapshot?.diagnostics, !diagnostics.isEmpty {
                List(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    VStack(alignment: .leading, spacing: 5) {
                        Label(
                            diagnostic.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                            systemImage: icon
                        )
                        .themeFont(.headline)
                        Text(diagnostic.message)
                        if let path = diagnostic.path {
                            Text(path.value)
                                .themeFont(.caption, design: .monospaced)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ContentUnavailableView("No Issues", systemImage: "checkmark.shield")
            }
        }
        .navigationTitle("Issues")
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
        }
    }

    private var icon: String {
        "exclamationmark.triangle"
    }
}
