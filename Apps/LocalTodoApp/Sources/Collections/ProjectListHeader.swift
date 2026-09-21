import SwiftUI

struct ProjectListHeader: View {
    let model: WorkspaceModel
    let draft: ProjectDraft
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(TaskMarkdown.inline(draft.title, links: false))
                .themeFont(.largeTitle)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .help(draft.title)
            Text(draft.status.rawValue.capitalized)
                .themeFont(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            if compact {
                editButton.labelStyle(.iconOnly)
            } else {
                editButton.labelStyle(.titleOnly)
            }
        }
    }

    private var editButton: some View {
        Button("Edit Project", systemImage: "pencil") { model.editProject() }
            .fixedSize()
            .help("Edit Project")
    }
}
