import AppKit
import LocalTodoDomain
import SwiftUI

struct TaskInspectorView: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft

    var body: some View {
        Form {
            TextField("Title", text: $draft.title)
                .font(.headline)
            Picker("Status", selection: $draft.status) {
                ForEach(TaskStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Priority", selection: $draft.priority) {
                Text("None").tag(TaskPriority?.none)
                ForEach(TaskPriority.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag(Optional($0)) }
            }
            TextField("Scheduled (YYYY-MM-DD)", text: $draft.scheduled)
            TextField("Deadline (YYYY-MM-DD)", text: $draft.deadline)
            DisclosureGroup("Organize") {
                TextField("Project path", text: $draft.project)
                TextField("Area path", text: $draft.area)
                TextField("Tags, comma separated", text: $draft.tags)
            }
            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .font(.body)
                    .frame(minHeight: 160)
            }
            Section("File") {
                Text(draft.path.value)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                HStack {
                    Button("Reveal in Finder") { reveal() }
                    Button("Open Externally") { openExternally() }
                }
            }
            Button("Save Changes") { save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!draft.isDirty || draft.isSaving)
            if draft.isDirty {
                Button("Discard Changes", role: .destructive) { model.discardChanges(for: draft.path) }
                    .disabled(draft.isSaving)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical)
    }

    private func save() {
        Task { await model.updateTask(draft) }
    }

    private func fileURL() -> URL? {
        model.rootURL?.appendingPathComponent(draft.path.value)
    }

    private func reveal() {
        guard let url = fileURL() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openExternally() {
        guard let url = fileURL() else { return }
        NSWorkspace.shared.open(url)
    }
}
