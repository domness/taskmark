import LocalTodoDomain
import LocalTodoWorkspace
import SwiftUI

struct MobileFilterEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let workspace: MobileWorkspace
    let originalName: String?
    @State var name: String
    @State var view: TaskView
    @State var text: String
    @State var includeCompleted: Bool
    @State var sort: TaskSort
    @State var statuses: Set<TaskStatus>
    @State var priorities: Set<TaskPriority>
    @State var includesNoPriority: Bool
    @State var projectPath: String
    @State var areaPath: String
    @State var tagsText: String
    @State var scheduledFrom: String
    @State var scheduledThrough: String
    @State var deadlineFrom: String
    @State var deadlineThrough: String
    @State private var confirmsDeletion = false
    @State var pendingConflictFilter: SavedTaskFilter?
    @State var pendingCheckpoint: FilterDraftCheckpoint?
    @State var checkpointGeneration: UInt64 = 0
    @State var baseRevision: String?
    @State var baselineFingerprint = ""
    @State var didFinishLoading = false
    @State var recoveredDraft = false
    @State var isFinished = false

    init(
        workspace: MobileWorkspace,
        existing: SavedTaskFilter? = nil,
        checkpointOriginalName: String? = nil
    ) {
        self.workspace = workspace
        originalName = checkpointOriginalName ?? existing?.name
        let query = existing?.query ?? TaskQuery(sort: .priority)
        _name = State(initialValue: existing?.name ?? "")
        _view = State(initialValue: TaskView(scope: query.scope) ?? .all)
        _text = State(initialValue: query.text)
        _includeCompleted = State(initialValue: query.includeCompleted)
        _sort = State(initialValue: query.sort)
        _statuses = State(initialValue: query.filters.statuses)
        _priorities = State(initialValue: query.filters.priorities)
        _includesNoPriority = State(initialValue: query.filters.includesNoPriority)
        _projectPath = State(initialValue: query.filters.project?.value ?? "")
        _areaPath = State(initialValue: query.filters.area?.value ?? "")
        _tagsText = State(initialValue: query.filters.tags.sorted().joined(separator: "\n"))
        _scheduledFrom = State(initialValue: query.filters.scheduled.start?.description ?? "")
        _scheduledThrough = State(initialValue: query.filters.scheduled.end?.description ?? "")
        _deadlineFrom = State(initialValue: query.filters.deadline.start?.description ?? "")
        _deadlineThrough = State(initialValue: query.filters.deadline.end?.description ?? "")
        _baseRevision = State(initialValue: workspace.session.savedFilters.revision?.value)
    }

    var body: some View {
        Form {
            if recoveredDraft {
                Section { Label("Draft recovered on this device", systemImage: "arrow.counterclockwise") }
            } else if pendingCheckpoint != nil {
                Section("Recovered Draft") {
                    Text("The saved-filter file changed after this draft was saved.")
                    Button("Apply Recovered Values") { applyPendingCheckpoint() }
                    Button("Discard Recovered Draft", role: .destructive) {
                        Task { await discardCheckpoint() }
                    }
                }
            }
            Section("Saved Filter") { TextField("Name", text: $name) }
            Section("Query") {
                Picker("View", selection: $view) {
                    ForEach(TaskView.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                TextField("Search text", text: $text)
                Toggle("Include completed", isOn: $includeCompleted)
                Picker("Sort", selection: $sort) {
                    ForEach(TaskSort.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
            }
            Section("Statuses") {
                ForEach(TaskStatus.allCases, id: \.self) { value in
                    Toggle(value.rawValue.capitalized, isOn: setBinding(value, in: $statuses))
                }
            }
            Section("Priorities") {
                ForEach(TaskPriority.allCases, id: \.self) { value in
                    Toggle(value.rawValue.uppercased(), isOn: setBinding(value, in: $priorities))
                }
                Toggle("No priority", isOn: $includesNoPriority)
            }
            Section("Organization") {
                Picker("Project", selection: $projectPath) {
                    Text("Any").tag("")
                    ForEach(projects, id: \.path) { Text($0.title).tag($0.path.value) }
                }
                Picker("Area", selection: $areaPath) {
                    Text("Any").tag("")
                    ForEach(areas, id: \.path) { Text($0.title).tag($0.path.value) }
                }
                TextField("Required tags, one per line", text: $tagsText, axis: .vertical)
            }
            Section("Date Ranges (YYYY-MM-DD)") {
                TextField("Scheduled from", text: $scheduledFrom)
                TextField("Scheduled through", text: $scheduledThrough)
                TextField("Deadline from", text: $deadlineFrom)
                TextField("Deadline through", text: $deadlineThrough)
            }
            if originalName != nil {
                Section { Button("Delete Saved Filter", role: .destructive) { confirmsDeletion = true } }
            }
        }
        .navigationTitle(originalName == nil ? "New Filter" : "Edit Filter")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Menu("Close") {
                    Button("Keep Draft") { dismiss() }
                    Button("Discard Draft", role: .destructive) {
                        Task {
                            isFinished = true
                            await discardCheckpoint()
                            dismiss()
                        }
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }.disabled(name.isEmpty)
            }
        }
        .confirmationDialog("Delete this saved filter?", isPresented: $confirmsDeletion) {
            Button("Delete", role: .destructive) { Task { await delete() } }
        }
        .confirmationDialog(
            "The saved-filter file changed on another client",
            isPresented: Binding(
                get: { pendingConflictFilter != nil },
                set: {
                    if !$0 {
                        pendingConflictFilter = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Reload External Changes") {
                pendingConflictFilter = nil
                Task { await workspace.refresh() }
            }
            Button("Keep My Filter and Rebase") {
                guard let filter = pendingConflictFilter else { return }
                Task {
                    if await workspace.resolveFilterConflictKeepingLocal(filter, replacing: originalName) {
                        isFinished = true
                        await discardCheckpoint()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Taskmark will reload the whole document and revalidate it before applying your choice.")
        }
        .task {
            baselineFingerprint = draftFingerprint
            await loadCheckpoint()
            didFinishLoading = true
        }
        .task(id: draftFingerprint) {
            try? await Task.sleep(for: .milliseconds(600))
            await checkpointIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { await checkpointIfNeeded() }
            }
        }
        .onDisappear { Task { await checkpointIfNeeded() } }
    }
}
