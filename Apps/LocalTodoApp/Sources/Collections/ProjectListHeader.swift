import SwiftUI

struct ProjectListHeader: View {
    let model: WorkspaceModel
    let draft: ProjectDraft

    var body: some View {
        HStack {
            Text(draft.title).font(.headline)
            Text(draft.status.rawValue.capitalized).foregroundStyle(.secondary)
            Spacer()
            Button("Edit Project") { model.editProject() }
        }
        .padding(12)
    }
}
