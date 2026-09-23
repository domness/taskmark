import LocalTodoDomain
import SwiftUI

struct TaskInspectorView: View {
    let model: WorkspaceModel
    @Bindable var draft: TaskDraft
    @State private var isTitleEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    TaskInspectorHeader(model: model, draft: draft, isTitleEditing: $isTitleEditing)
                    TaskNotesView(draft: draft)
                        .padding(.leading, 26)
                    TaskChecklistView(model: model, draft: draft)
                        .padding(.leading, 26)
                }
                planning
                organization
                TaskInspectorFileDetails(model: model, draft: draft)
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
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .disabled(model.deletingTaskPaths.contains(draft.path))
        .onAppear { focusTitleIfRequested() }
        .onChange(of: model.titleEditRequest) { _, _ in focusTitleIfRequested() }
    }

    private var planning: some View {
        InspectorPropertySection("Planning") {
            dateRow("Scheduled", image: "calendar", keyPath: \.scheduled, actionName: "Change Scheduled Date")
            dateRow("Deadline", image: "flag", keyPath: \.deadline, actionName: "Change Deadline")
            InspectorPropertyRow("Status") {
                Picker("Status", selection: status) {
                    ForEach(TaskStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
            }
            InspectorPropertyRow("Priority") {
                Picker("Priority", selection: priority) {
                    Text("None").tag(TaskPriority?.none)
                    ForEach(TaskPriority.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag(Optional($0)) }
                }
            }
        }
    }

    private var organization: some View {
        InspectorPropertySection("Organization") {
            InspectorPropertyRow("Project") {
                Picker("Project", selection: project) {
                    Text("Add project").tag("")
                    ForEach(projects, id: \.path) { project in
                        Text(model.projectDisplayTitle(project.path)).tag(project.path.value)
                    }
                    if !draft.project.isEmpty, !projects.contains(where: { $0.path.value == draft.project }) {
                        Text("Missing: \(draft.project)").tag(draft.project)
                    }
                }
            }
            InspectorPropertyRow("Area") {
                Picker("Area", selection: area) {
                    Text("Add area").tag("")
                    ForEach(areas, id: \.path) { area in
                        Text(model.areaDisplayTitle(area.path)).tag(area.path.value)
                    }
                    if !draft.area.isEmpty, !areas.contains(where: { $0.path.value == draft.area }) {
                        Text("Missing: \(draft.area)").tag(draft.area)
                    }
                }
            }
            TaskTagsView(model: model, draft: draft)
            TaskRecurrenceView(model: model, draft: draft)
        }
    }

    private func dateRow(
        _ title: String, image: String, keyPath: ReferenceWritableKeyPath<TaskDraft, String>, actionName: String
    ) -> some View {
        InspectorPropertyRow(title) {
            CalendarDateField(
                label: title,
                systemImage: image,
                text: draft[keyPath: keyPath],
                calendar: model.planningCalendar,
                now: model.clock,
                presentation: .inspector,
                onCalendarChange: { model.changeDraft(draft, keyPath: keyPath, to: $0, actionName: actionName) }
            )
        }
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
            isTitleEditing = true
            model.consumeTitleEditRequest(at: draft.path)
        }
    }
}
