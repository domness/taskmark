import LocalTodoDomain
import LocalTodoMarkdown
import LocalTodoWorkspace
import SwiftUI

struct MobileTaskListView: View {
    let workspace: MobileWorkspace
    let route: WorkspaceRoute
    var selectedPath: Binding<VaultPath?>?
    @State private var isCapturing = false
    @State private var includeCompleted = false
    @State private var options: WorkspaceViewOptions
    @State private var order: WorkspaceCustomOrder

    init(
        workspace: MobileWorkspace,
        route: WorkspaceRoute,
        selectedPath: Binding<VaultPath?>? = nil
    ) {
        self.workspace = workspace
        self.route = route
        self.selectedPath = selectedPath
        _options = State(initialValue: workspace.viewOptions(for: route))
        _order = State(initialValue: workspace.customOrder(for: route))
    }

    var body: some View {
        List(selection: selectedPath) {
            if options.grouping == .none {
                ForEach(displayedTasks, id: \.path) { task in
                    taskRow(task)
                }
                .onMove(perform: moveTasks)
            } else {
                ForEach(taskGroups) { group in
                    Section(group.title) {
                        ForEach(group.tasks, id: \.path) { task in
                            taskRow(task)
                        }
                        .onMove { offsets, destination in
                            moveTasks(in: group, from: offsets, to: destination)
                        }
                    }
                }
            }
        }
        .navigationTitle(route.title)
        .overlay {
            if displayedTasks.isEmpty {
                ContentUnavailableView(
                    route == .search ? "Search Tasks" : "No Tasks",
                    systemImage: route == .search ? "magnifyingglass" : "checklist"
                )
            }
        }
        .refreshable { await workspace.refresh() }
        .safeAreaInset(edge: .top) {
            if workspace.snapshot?.scanCompleteness != .complete {
                HStack {
                    Label("Vault data is incomplete", systemImage: "icloud.and.arrow.down")
                    Spacer()
                    Button("Retry") { Task { await workspace.refresh() } }
                }
                .font(.caption)
                .padding(.horizontal).padding(.vertical, 8)
                .background(.bar)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    Task { await workspace.undo() }
                }
                .disabled(!workspace.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                Button("Redo", systemImage: "arrow.uturn.forward") {
                    Task { await workspace.redo() }
                }
                .disabled(!workspace.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            if let collectionPath {
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink {
                        MobileCollectionDetailView(workspace: workspace, path: collectionPath)
                    } label: {
                        Label("Collection Details", systemImage: "info.circle")
                    }
                }
            }
            if let filter = savedFilter {
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink {
                        MobileFilterEditorView(workspace: workspace, existing: filter)
                    } label: {
                        Label("Edit Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Task", systemImage: "plus") { isCapturing = true }
                    .accessibilityIdentifier("add-task")
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("View Options", systemImage: "slider.horizontal.3") {
                    Toggle("Show Completed", isOn: $includeCompleted)
                    Toggle("Show Projects", isOn: optionBinding(\.showsProject))
                    Toggle("Show Areas", isOn: optionBinding(\.showsArea))
                    Toggle("Show Tags", isOn: optionBinding(\.showsTags))
                    Picker("Group", selection: optionBinding(\.grouping)) {
                        ForEach(WorkspaceViewOptions.Grouping.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    Picker("Sort", selection: optionBinding(\.sort)) {
                        Text("Default").tag(TaskSort?.none)
                        ForEach(TaskSort.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) }
                    }
                    Toggle("Custom Order", isOn: customOrderBinding)
                    if order.isEnabled {
                        EditButton()
                    }
                }
            }
        }
        .sheet(isPresented: $isCapturing) { MobileCaptureView(workspace: workspace, route: route) }
    }

    private var collectionPath: VaultPath? {
        switch route {
        case let .project(path), let .area(path): path
        default: nil
        }
    }

    private var savedFilter: SavedTaskFilter? {
        guard case let .savedFilter(name) = route else { return nil }
        return workspace.savedFilters.first { $0.name == name }
    }

    private var displayedTasks: [TodoTask] {
        workspace.tasks(for: route, includeCompleted: includeCompleted)
    }

    private var taskGroups: [MobileTaskGroup] {
        let grouped = Dictionary(grouping: displayedTasks) { task in
            switch options.grouping {
            case .project: task.project?.value ?? "No Project"
            case .area: task.area?.value ?? "No Area"
            case .none: "Tasks"
            }
        }
        return grouped.map { MobileTaskGroup(title: $0.key, tasks: $0.value) }.sorted { $0.title < $1.title }
    }

    @ViewBuilder private func taskRow(_ task: TodoTask) -> some View {
        if selectedPath != nil {
            MobileTaskRow(workspace: workspace, task: task, options: options).tag(task.path)
        } else {
            NavigationLink {
                MobileTaskDetailView(workspace: workspace, path: task.path)
            } label: {
                MobileTaskRow(workspace: workspace, task: task, options: options)
            }
        }
    }

    private func optionBinding<Value>(_ keyPath: WritableKeyPath<WorkspaceViewOptions, Value>) -> Binding<Value> {
        Binding(
            get: { options[keyPath: keyPath] },
            set: { value in
                options[keyPath: keyPath] = value
                Task { await workspace.setViewOptions(options, for: route) }
            }
        )
    }

    private var customOrderBinding: Binding<Bool> {
        Binding(
            get: { order.isEnabled },
            set: { enabled in
                order.isEnabled = enabled
                if enabled, order.paths.isEmpty {
                    order.paths = displayedTasks.map(\.path)
                }
                Task { await workspace.setCustomOrder(order, for: route) }
            }
        )
    }

    private func moveTasks(from offsets: IndexSet, to destination: Int) {
        guard order.isEnabled else { return }
        var moved = displayedTasks.map(\.path)
        moved.move(fromOffsets: offsets, toOffset: destination)
        persistVisibleOrder(moved)
    }

    private func moveTasks(in group: MobileTaskGroup, from offsets: IndexSet, to destination: Int) {
        guard order.isEnabled else { return }
        var groupPaths = group.tasks.map(\.path)
        groupPaths.move(fromOffsets: offsets, toOffset: destination)
        let groupSet = Set(groupPaths)
        var iterator = groupPaths.makeIterator()
        let moved = displayedTasks.map { groupSet.contains($0.path) ? iterator.next() ?? $0.path : $0.path }
        persistVisibleOrder(moved)
    }

    private func persistVisibleOrder(_ moved: [VaultPath]) {
        let visible = Set(moved)
        var iterator = moved.makeIterator()
        var merged = order.paths.map { visible.contains($0) ? iterator.next() ?? $0 : $0 }
        merged.append(contentsOf: iterator)
        order.paths = merged
        Task { await workspace.setCustomOrder(order, for: route) }
    }
}

private struct MobileTaskGroup: Identifiable {
    let title: String
    let tasks: [TodoTask]
    var id: String {
        title
    }
}

private struct MobileTaskRow: View {
    let workspace: MobileWorkspace
    let task: TodoTask
    let options: WorkspaceViewOptions
    private var isAvailable: Bool {
        guard let state = workspace.snapshot?.availability[task.path] else { return true }
        return state == .available
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await workspace.complete(task.path) }
            } label: {
                Image(systemName: task.status.isComplete ? "checkmark.circle.fill" : "circle")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .accessibilityLabel(task.status.isComplete ? "Reopen task" : "Complete task")
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title).strikethrough(task.status.isComplete)
                HStack {
                    if let scheduled = task.scheduled {
                        Text(scheduled.description)
                    }
                    if let priority = task.priority {
                        Text(priority.rawValue.uppercased())
                    }
                    if options.showsProject, let project = task.project {
                        Text(project.value)
                    }
                    if options.showsArea, let area = task.area {
                        Text(area.value)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                if options.showsTags, !task.tags.isEmpty {
                    Text(task.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !isAvailable {
                    Label("Waiting for file", systemImage: "icloud.and.arrow.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button(task.status.isComplete ? "Reopen" : "Complete") {
                Task { await workspace.complete(task.path) }
            }
            Button("Delete", role: .destructive) {
                Task { _ = await workspace.deleteTask(at: task.path) }
            }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                Task { _ = await workspace.duplicateTask(at: task.path) }
            }
            ShareLink(item: task.title, subject: Text("Taskmark task")) {
                Label("Share Title", systemImage: "square.and.arrow.up")
            }
            ShareLink(item: task.path.value) {
                Label("Share Path", systemImage: "doc.on.doc")
            }
        }
    }
}
