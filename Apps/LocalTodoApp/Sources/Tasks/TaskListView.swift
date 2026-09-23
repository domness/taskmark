import Foundation
import LocalTodoDomain
import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @Bindable var model: WorkspaceModel
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isListFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            listHeader
            FilterRouteHeader(model: model)
            if model.isQuickCapturePresented {
                QuickCaptureRow(model: model)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
            }
            listContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .themeSurface()
        .onChange(of: model.route) { _, route in
            isSearchFocused = route == .search
        }
        .onChange(of: model.searchText) { _, text in
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                model.route = .search
            }
        }
        .onChange(of: model.searchFocusRequest) { _, _ in
            model.route = .search
            isSearchFocused = true
        }
        .onAppear { isSearchFocused = model.route == .search }
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let draft = model.selectedProjectDraft {
                        ProjectListHeader(model: model, draft: draft, compact: true)
                    } else {
                        routeHeading
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                headerControls
                    .fixedSize()
            }
            if let draft = model.selectedProjectDraft, !draft.notes.isEmpty {
                Text(TaskMarkdown.inline(draft.notes, links: true))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if model.route == .search {
                TextField("Search tasks", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var headerControls: some View {
        HStack(spacing: 12) {
            Button("Search", systemImage: "magnifyingglass") {
                model.route = .search
                isSearchFocused = true
            }
            .labelStyle(.iconOnly)
            .help("Search Tasks (Command-F)")
            Button("New Task", systemImage: "plus") { model.beginQuickCapture() }
                .labelStyle(.iconOnly)
                .help("New Task (Command-N)")
            displayOptionsMenu
        }
        .buttonStyle(.borderless)
        .padding(8)
        .modifier(CanvasControlMaterial())
    }

    private var displayOptionsMenu: some View {
        Menu {
            TaskSortPicker(model: model)
            Section("Show in Rows") {
                Toggle("Project", isOn: metadataBinding(.project))
                Toggle("Area", isOn: metadataBinding(.area))
                Toggle("Tags", isOn: metadataBinding(.tags))
            }
            AppearanceMenu(model: model)
            Picker("Group By", selection: groupingBinding) {
                ForEach(TaskListGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping)
                }
            }
        } label: {
            Image(systemName: model
                .stylesheetDiagnostic == nil ? "line.3.horizontal.decrease" : "exclamationmark.triangle")
                .accessibilityLabel("View Options")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Choose row details and grouping for this view")
    }

    @ViewBuilder
    private var listContent: some View {
        if model.route == .search, !model.hasActiveSearch {
            ContentUnavailableView(
                "Search Tasks",
                systemImage: "magnifyingglass",
                description: Text("Search titles, notes, and tags across the vault.")
            )
        } else if model.visibleTasks.isEmpty {
            ContentUnavailableView(
                model.route == .search ? "No Results" : "No Tasks",
                systemImage: model.route == .search ? "magnifyingglass" : "checkmark.circle",
                description: Text(
                    model.route == .search
                        ? "Try a different search."
                        : "Capture a task or choose another view."
                )
            )
        } else {
            List(selection: selection) {
                ForEach(taskSections) { section in
                    if let title = section.title {
                        Section(title) {
                            taskRows(section.tasks)
                        }
                    } else {
                        taskRows(section.tasks)
                    }
                }
            }
            .listStyle(.inset)
            .focused($isListFocused)
            .onKeyPress(characters: CharacterSet(charactersIn: "\u{8}\u{7F}")) { press in
                guard press.modifiers.isEmpty, let path = model.selectedTaskPath else { return .ignored }
                Task { await model.deleteTask(at: path) }
                return .handled
            }
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                guard let path = model.selectedTaskPath else { return }
                Task { await model.deleteTask(at: path) }
            }
        }
    }

    private func taskRows(_ tasks: [TodoTask]) -> some View {
        let context = model.taskReorderContext(for: tasks)
        return ForEach(tasks, id: \.path) { task in
            TaskRow(
                model: model, task: task,
                displayOptions: model.currentTaskListDisplayOptions, reorderContext: context,
                onSelect: { openTaskDetails(task.path) }
            )
            .tag(task.path)
            .listRowSeparator(.hidden)
        }
        .onInsert(of: model.isCustomTaskOrder ? [UTType.localTodoTaskReference] : []) { destination, providers in
            model.insertDraggedTask(from: providers, at: destination, context: context)
        }
    }
}

private extension TaskListView {
    var taskSections: [TaskListSection] {
        switch model.currentTaskListDisplayOptions.grouping {
        case .none:
            [TaskListSection(id: "all", title: nil, tasks: model.visibleTasks)]
        case .project:
            groupedSections(
                by: \.project,
                emptyTitle: "No Project",
                title: model.projectDisplayTitle
            )
        case .area:
            groupedSections(
                by: \.area,
                emptyTitle: "No Area",
                title: model.areaDisplayTitle
            )
        }
    }

    func groupedSections(
        by keyPath: KeyPath<TodoTask, VaultPath?>,
        emptyTitle: String,
        title: (VaultPath) -> String
    ) -> [TaskListSection] {
        let groups = Dictionary(grouping: model.visibleTasks) { $0[keyPath: keyPath] }
        return groups.map { path, tasks in
            TaskListSection(
                id: path?.value ?? "none",
                title: path.map(title) ?? emptyTitle,
                tasks: tasks
            )
        }
        .sorted { lhs, rhs in
            if lhs.id == "none" {
                return false
            }
            if rhs.id == "none" {
                return true
            }
            let titleOrder = (lhs.title ?? "").localizedStandardCompare(rhs.title ?? "")
            return titleOrder == .orderedSame ? lhs.id < rhs.id : titleOrder == .orderedAscending
        }
    }
}

private extension TaskListView {
    func openTaskDetails(_ path: VaultPath) {
        model.selectTask(path)
        model.isInspectorPresented = true
        isListFocused = true
    }

    func metadataBinding(_ field: TaskListMetadataField) -> Binding<Bool> {
        Binding(
            get: {
                let options = model.currentTaskListDisplayOptions
                return switch field {
                case .project: options.showsProject
                case .area: options.showsArea
                case .tags: options.showsTags
                }
            },
            set: { model.setTaskListMetadata(field, isVisible: $0) }
        )
    }

    private var groupingBinding: Binding<TaskListGrouping> {
        Binding(
            get: { model.currentTaskListDisplayOptions.grouping },
            set: { model.setTaskListGrouping($0) }
        )
    }
}

private extension TaskListView {
    var routeHeading: some View {
        Text(model.route.title)
            .themeFont(.largeTitle)
            .fontWeight(.bold)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    var selection: Binding<VaultPath?> {
        Binding(
            get: { model.selectedTaskPath },
            set: {
                model.selectTask($0)
            }
        )
    }
}

private struct TaskListSection: Identifiable {
    let id: String
    let title: String?
    let tasks: [TodoTask]
}
