import LocalTodoDomain
import SwiftUI

struct FilterEditorView: View {
    let model: WorkspaceModel
    @Bindable var state: FilterWorkspaceState
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("Filter Criteria", isExpanded: $isExpanded) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("View", selection: $state.editor.view) {
                            ForEach(TaskView.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        TextField("Text in title, notes or tags", text: $state.editor.text)
                        projectPicker
                        areaPicker
                        HStack {
                            statusMenu
                            priorityMenu
                        }
                        TextField("Required tags, comma separated", text: $state.editor.tags)
                        Text("All selected tags must match. Statuses and priorities are alternatives.")
                            .themeFont(.caption).foregroundStyle(.secondary)
                        FilterDateRangesView(model: model, editor: $state.editor)
                        Toggle("Include completed and canceled tasks", isOn: $state.editor.includeCompleted)
                        Picker("Sort", selection: $state.editor.sort) {
                            ForEach(TaskSort.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxHeight: 320)
            }
            if let message = state.editor.validationMessage {
                Label(message, systemImage: "exclamationmark.triangle")
            }
            HStack {
                TextField("Filter name", text: $state.name)
                Button(state.editingName == state.name ? "Update Filter" : "Save Filter") {
                    Task { await model.saveWorkingFilter() }
                }
                .disabled(state.isSaving || state.editor.validationMessage != nil || state.loadError != nil || state
                    .hasConflict)
                Button("Clear") { model.beginFilterEditing() }
                    .disabled(state.isSaving)
            }
            if let message = state.saveError ?? state.loadError {
                Label(message, systemImage: "exclamationmark.triangle")
                    .textSelection(.enabled)
            }
            if state.hasConflict {
                HStack {
                    Button("Use File Version") {
                        Task {
                            await model.refreshSavedFilters()
                            model.beginFilterEditing(name: state.editingName)
                        }
                    }
                    Button("Keep Working Filter") { Task { await model.keepWorkingFilterAfterReload() } }
                }
            } else if state.loadError != nil {
                Button("Reload Filters") { Task { await model.refreshSavedFilters() } }
            }
        }
        .padding(12)
    }

    private var projectPicker: some View {
        Picker("Project", selection: $state.editor.project) {
            Text("Any Project").tag("")
            ForEach(model.activeProjects + model.inactiveProjects, id: \.path) { project in
                Text(model.projectDisplayTitle(project.path)).tag(project.path.value)
            }
            if missingProject {
                Text("Missing: \(state.editor.project)").tag(state.editor.project)
            }
        }
    }

    private var statusMenu: some View {
        Menu(state.editor.statuses.isEmpty ? "Any Status" : "Statuses (\(state.editor.statuses.count))") {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                Toggle(status.rawValue.capitalized, isOn: membership(\.statuses, value: status))
            }
        }
    }

    private var areaPicker: some View {
        Picker("Area", selection: $state.editor.area) {
            Text("Any Area").tag("")
            ForEach(
                model.snapshot?.areas.values.map(\.value).sorted { $0.title < $1.title } ?? [],
                id: \.path
            ) { area in
                Text(model.areaDisplayTitle(area.path)).tag(area.path.value)
            }
            if missingArea {
                Text("Missing: \(state.editor.area)").tag(state.editor.area)
            }
        }
    }

    private var priorityMenu: some View {
        Menu("Priorities") {
            ForEach(TaskPriority.allCases, id: \.self) { priority in
                Toggle(priority.rawValue.uppercased(), isOn: membership(\.priorities, value: priority))
            }
            Toggle("No Priority", isOn: $state.editor.includesNoPriority)
        }
    }

    private var missingProject: Bool {
        !state.editor.project.isEmpty
            && !(model.activeProjects + model.inactiveProjects).contains { $0.path.value == state.editor.project }
    }

    private var missingArea: Bool {
        !state.editor.area.isEmpty && model.snapshot?.areas.keys.contains { $0.value == state.editor.area } != true
    }

    private func membership<Value: Hashable>(
        _ keyPath: WritableKeyPath<TaskFilterEditor, Set<Value>>, value: Value
    ) -> Binding<Bool> {
        Binding(get: { state.editor[keyPath: keyPath].contains(value) }, set: { enabled in
            if enabled {
                state.editor[keyPath: keyPath].insert(value)
            } else {
                state.editor[keyPath: keyPath].remove(value)
            }
        })
    }
}
