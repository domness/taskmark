import AppKit
import LocalTodoDomain
import SwiftUI

struct TaskInspectorView: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            TextField("Title", text: $draft.title)
                .font(.headline)
                .focused($isTitleFocused)
            Picker("Status", selection: status) {
                ForEach(TaskStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Priority", selection: priority) {
                Text("None").tag(TaskPriority?.none)
                ForEach(TaskPriority.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag(Optional($0)) }
            }
            HStack {
                CalendarDateField(
                    label: "Scheduled",
                    systemImage: "calendar",
                    text: draft.scheduled,
                    calendar: model.planningCalendar,
                    onCalendarChange: {
                        model.changeDraft(
                            draft,
                            keyPath: \.scheduled,
                            to: $0,
                            actionName: "Change Scheduled Date"
                        )
                    }
                )
                CalendarDateField(
                    label: "Deadline",
                    systemImage: "flag",
                    text: draft.deadline,
                    calendar: model.planningCalendar,
                    onCalendarChange: {
                        model.changeDraft(draft, keyPath: \.deadline, to: $0, actionName: "Change Deadline")
                    }
                )
                Spacer()
            }
            Section {
                Picker("Project", selection: project) {
                    Text("None").tag("")
                    ForEach(projects, id: \.path) { project in
                        Text(model.projectDisplayTitle(project.path)).tag(project.path.value)
                    }
                    if !draft.project.isEmpty, !projects.contains(where: { $0.path.value == draft.project }) {
                        Text("Missing: \(draft.project)").tag(draft.project)
                    }
                }
                Picker("Area", selection: area) {
                    Text("None").tag("")
                    ForEach(areas, id: \.path) { area in
                        Text(model.areaDisplayTitle(area.path)).tag(area.path.value)
                    }
                    if !draft.area.isEmpty, !areas.contains(where: { $0.path.value == draft.area }) {
                        Text("Missing: \(draft.area)").tag(draft.area)
                    }
                }
                TaskTagsView(model: model, draft: draft)
            }
            TaskRecurrenceView(model: model, draft: draft)
            TaskChecklistView(model: model, draft: draft)
            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .font(.body)
                    .frame(minHeight: 160)
                    .accessibilityLabel("Task notes, Markdown")
            }
            Section("File") {
                LabeledContent("Created", value: model.formattedTimestamp(draft.sourceTask.createdAt))
                LabeledContent("Updated", value: model.formattedTimestamp(draft.sourceTask.updatedAt))
                Text(draft.path.value)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                HStack {
                    Button("Reveal in Finder") { reveal() }
                    Button("Open Externally") { openExternally() }
                }
            }
            if let sourceUnavailableMessage = draft.sourceUnavailableMessage {
                Section("Task File Unavailable") {
                    Text(sourceUnavailableMessage)
                        .foregroundStyle(.secondary)
                    HStack {
                        if draft.canRecreateSource {
                            Button("Recreate Task") { Task { await model.recreateTask(draft) } }
                        } else {
                            Button("Save Copy") { Task { await model.saveTaskCopy(draft) } }
                        }
                        Button("Discard Changes") { model.discardChanges(for: draft.path) }
                    }
                }
            } else if draft.hasConflicts {
                Section("Changed In File") {
                    Text("Conflicting changes: \(conflictNames).")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Use File Version") { model.discardChanges(for: draft.path) }
                        Button("Keep My Changes") { draft.resolveConflictsKeepingLocalChanges() }
                    }
                }
            }
            saveStatus
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .disabled(model.deletingTaskPaths.contains(draft.path))
        .padding(.vertical)
        .onAppear { focusTitleIfRequested() }
        .onChange(of: model.titleEditRequest) { _, _ in focusTitleIfRequested() }
    }

    @ViewBuilder
    private var saveStatus: some View {
        if draft.sourceUnavailableMessage != nil {
            Label("Choose how to preserve or discard these changes", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else if draft.hasConflicts {
            Label("Choose which conflicting changes to keep", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else if draft.isSaving {
            Label("Saving", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        } else if draft.validationError != nil {
            Label("Fix invalid fields to save", systemImage: "exclamationmark.circle")
                .foregroundStyle(.secondary)
        } else if draft.isDirty {
            Label("Waiting to save", systemImage: "clock")
                .foregroundStyle(.secondary)
        } else {
            Label("Saved", systemImage: "checkmark")
                .foregroundStyle(.secondary)
        }
    }

    private var status: Binding<TaskStatus> {
        Binding(
            get: { draft.status },
            set: { model.changeTaskStatus(draft, to: $0) }
        )
    }

    private var priority: Binding<TaskPriority?> {
        Binding(
            get: { draft.priority },
            set: { model.changeDraft(draft, keyPath: \.priority, to: $0, actionName: "Change Priority") }
        )
    }

    private var project: Binding<String> {
        Binding(
            get: { draft.project },
            set: { model.changeDraft(draft, keyPath: \.project, to: $0, actionName: "Change Project") }
        )
    }

    private var area: Binding<String> {
        Binding(
            get: { draft.area },
            set: { model.changeDraft(draft, keyPath: \.area, to: $0, actionName: "Change Area") }
        )
    }

    private var projects: [Project] {
        let assignedInactive = model.inactiveProjects.filter { $0.path.value == draft.project }
        return model.activeProjects + assignedInactive
    }

    private var areas: [Area] {
        model.snapshot?.areas.values.map(\.value).sorted { $0.title < $1.title } ?? []
    }

    private var conflictNames: String {
        draft.conflictedFields
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
    }

    private func focusTitleIfRequested() {
        if model.titleEditingPath == draft.path {
            isTitleFocused = true
            model.consumeTitleEditRequest(at: draft.path)
        }
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
