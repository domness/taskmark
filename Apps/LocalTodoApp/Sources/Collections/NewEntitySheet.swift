import SwiftUI

struct NewEntitySheet: View {
    let model: WorkspaceModel
    let kind: NewEntityKind
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var path = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New \(kind.rawValue.capitalized)")
                .themeFont(.title2, weight: .semibold)
            TextField("Title", text: $title)
            TextField("Vault-relative path", text: $path, prompt: Text(defaultPath))
                .font(.body.monospaced())
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var defaultPath: String {
        "\(kind == .project ? "Projects" : "Areas")/Name.md"
    }

    private func create() {
        let resolvedPath = path.isEmpty
            ? "\(kind == .project ? "Projects" : "Areas")/\(title).md"
            : path
        Task { await model.createCollection(kind: kind, path: resolvedPath, title: title) }
    }
}
