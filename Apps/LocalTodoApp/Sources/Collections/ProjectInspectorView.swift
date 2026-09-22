import LocalTodoDomain
import SwiftUI

struct ProjectInspectorView: View {
    let model: WorkspaceModel
    @Bindable var draft: ProjectDraft
    @State private var isTitleEditing = false
    @State private var isNotesEditing = false

    var body: some View {
        Form {
            TaskMarkdownField(
                text: $draft.title,
                kind: .title,
                subject: "Project",
                isEditing: $isTitleEditing
            )
            Picker("Project status", selection: Binding(
                get: { draft.status },
                set: { model.changeProjectField(draft, field: .status, to: $0.rawValue) }
            )) {
                ForEach(ProjectStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Button(draft.status == .done || draft.status == .canceled ? "Reopen Project" : "Complete Project") {
                model.toggleProjectCompletion(draft)
            }
            .disabled(!draft.conflicts.isEmpty || draft.unavailableMessage != nil)
            Text("Project status does not change its tasks.")
                .themeFont(.caption).foregroundStyle(.secondary)
            Section {
                TaskMarkdownField(
                    text: $draft.notes,
                    kind: .notes,
                    subject: "Project",
                    isEditing: $isNotesEditing
                )
            }
            if let message = draft.unavailableMessage {
                Section("Project File Unavailable") {
                    Text(message)
                    Button("Discard Changes") { model.discardProjectChanges(draft) }
                }
            } else if !draft.conflicts.isEmpty {
                Section("Changed In File") {
                    Text("Conflicting changes: \(draft.conflicts.map(\.rawValue).sorted().joined(separator: ", ")).")
                    Button("Use File Version") { model.discardProjectChanges(draft) }
                    Button("Keep My Changes") { draft.keepLocalChanges() }
                }
            } else if let error = draft.validationError ?? draft.saveError {
                Label(error, systemImage: "exclamationmark.triangle")
                Button("Retry Save") { Task { await model.updateProject(draft) } }
                    .disabled(draft.validationError != nil)
            } else {
                Label(
                    draft.isSaving ? "Saving" : draft.isDirty ? "Waiting to save" : "Saved",
                    systemImage: draft.isDirty ? "clock" : "checkmark"
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .disabled(model.deletingCollectionPaths.contains(draft.path))
        .padding(.vertical)
        .onAppear { focusTitleIfRequested() }
        .onChange(of: model.titleEditRequest) { _, _ in focusTitleIfRequested() }
    }

    private func focusTitleIfRequested() {
        if model.titleEditingPath == draft.path {
            isTitleEditing = true
            model.consumeTitleEditRequest(at: draft.path)
        }
    }
}
