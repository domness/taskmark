import AppKit
import SwiftUI

struct TaskInspectorFileDetails: View {
    let model: WorkspaceModel
    let draft: TaskDraft
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            DisclosureGroup("File details", isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(draft.path.value)
                        .themeFont(.caption, design: .monospaced)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    LabeledContent("Created", value: model.formattedTimestamp(draft.sourceTask.createdAt))
                    LabeledContent("Updated", value: model.formattedTimestamp(draft.sourceTask.updatedAt))
                    ViewThatFits(in: .horizontal) {
                        HStack { fileActions }
                        VStack(alignment: .leading, spacing: 8) { fileActions }
                    }
                    if !draft.isDirty, !draft.isSaving, !draft.hasConflicts, draft.sourceUnavailableMessage == nil {
                        Label("Saved", systemImage: "checkmark")
                    }
                }
                .padding(.top, 12)
            }
            .themeFont(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("inspector-file-details")
        }
    }

    private var fileActions: some View {
        Group {
            Button("Reveal in Finder") {
                guard let url = fileURL else { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("Open Externally") {
                guard let url = fileURL else { return }
                NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(.borderless)
    }

    private var fileURL: URL? {
        model.rootURL?.appendingPathComponent(draft.path.value)
    }
}
