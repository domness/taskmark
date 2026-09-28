import LocalTodoMarkdown
import SwiftUI
import UniformTypeIdentifiers

struct MobileProviderConflictView: View {
    let workspace: MobileWorkspace
    let conflict: VaultProviderConflict
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAlternativeID: String?
    @State private var isResolving = false

    private var selectedAlternative: VaultProviderVersion? {
        conflict.alternatives.first { $0.id == selectedAlternativeID } ?? conflict.alternatives.first
    }

    var body: some View {
        List {
            Section("File") {
                Text(conflict.path).font(.caption.monospaced()).textSelection(.enabled)
                Text(
                    "Review and export alternatives before choosing. "
                        + "Taskmark will recheck every version when you resolve."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Section("Current Content") {
                contentPreview(conflict.currentContent)
                ShareLink(
                    item: ProviderConflictExport(content: conflict.currentContent),
                    preview: SharePreview("Current \(conflict.path)")
                ) { Label("Export Current", systemImage: "square.and.arrow.up") }
                Button("Keep Current") { resolve(using: conflict.currentContent) }
                    .disabled(isResolving)
            }
            Section("Recoverable Alternative") {
                if conflict.alternatives.count > 1 {
                    Picker("Version", selection: alternativeSelection) {
                        ForEach(conflict.alternatives) { version in
                            Text(versionLabel(version)).tag(version.id)
                        }
                    }
                }
                if let selectedAlternative {
                    contentPreview(selectedAlternative.content)
                    ShareLink(
                        item: ProviderConflictExport(content: selectedAlternative.content),
                        preview: SharePreview("Alternative \(conflict.path)")
                    ) { Label("Export Alternative", systemImage: "square.and.arrow.up") }
                    Button("Use This Alternative") { resolve(using: selectedAlternative.content) }
                        .disabled(isResolving)
                }
            }
        }
        .navigationTitle("Resolve Conflict")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var alternativeSelection: Binding<String> {
        Binding(
            get: { selectedAlternativeID ?? conflict.alternatives[0].id },
            set: { selectedAlternativeID = $0 }
        )
    }

    @ViewBuilder private func contentPreview(_ data: Data) -> some View {
        if let text = String(data: data, encoding: .utf8) {
            Text(text).font(.caption.monospaced()).textSelection(.enabled)
        } else {
            Label("Binary content (\(data.count) bytes)", systemImage: "doc")
        }
    }

    private func versionLabel(_ version: VaultProviderVersion) -> String {
        if let date = version.modifiedAt {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return version.localizedName ?? "Alternative"
    }

    private func resolve(using content: Data) {
        isResolving = true
        Task {
            let succeeded = await workspace.resolveProviderConflict(conflict, choosing: content)
            isResolving = false
            if succeeded {
                dismiss()
            }
        }
    }
}

private struct ProviderConflictExport: Transferable {
    let content: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { $0.content }
    }
}
