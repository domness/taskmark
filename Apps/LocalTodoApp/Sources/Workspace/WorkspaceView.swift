import LocalTodoDomain
import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectorWidth: CGFloat = 340
    @State private var canvasWidth: CGFloat = 840
    @State private var tabState = WorkspaceTabState()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager

    init(model: WorkspaceModel, initialTabState: WorkspaceTabState = WorkspaceTabState()) {
        self.model = model
        _tabState = State(initialValue: initialTabState)
    }

    var body: some View {
        Group {
            if model.snapshot == nil {
                ContentUnavailableView {
                    Label("Start with a Vault", systemImage: "folder")
                } description: {
                    Text("Create a new folder-backed task vault, or open one you already use.")
                } actions: {
                    Button("Create New Vault") { Task { await model.createVault() } }
                        .keyboardShortcut(.defaultAction)
                    Button("Open Existing Vault") { Task { await model.chooseVault() } }
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } else {
                navigation
            }
        }
        .frame(minWidth: 840, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) { ConfigurationSaveStatus(model: model) }
        .disabled(model.isSavingConfiguration || model.isRemovingOrganization)
        .sheet(isPresented: $model.isCommandPalettePresented) {
            CommandPaletteView(model: model)
        }
        .sheet(item: $model.newEntityKind) { kind in
            NewEntitySheet(model: model, kind: kind)
        }
        .sheet(item: $model.rescheduleSelection) { selection in
            TaskRescheduleSheet(model: model, selection: selection)
        }
        .alert("Taskmark", isPresented: errorPresented) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        .onAppear { model.setUndoManager(undoManager) }
        .onChange(of: model.rootURL) { _, _ in
            if !tabState.isEmpty {
                tabState.removeAll()
            }
        }
        .onChange(of: model.route) { oldRoute, route in
            if oldRoute != route, !tabState.isEmpty {
                tabState.navigate(to: route)
            }
        }
        .background {
            WorkspaceTabCloseBridge(
                canCloseTab: tabState.tabs.count > 1,
                onCloseTab: closeSelectedTab
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private var navigation: some View {
        navigationSplit
            .toolbar { canvasToolbar }
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    private var navigationSplit: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                model: model,
                onNavigate: navigate,
                onOpenRouteInTab: openRouteInTab
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            canvas
                .frame(minWidth: 0, maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width in
                    if width > 0, width != canvasWidth {
                        canvasWidth = width
                    }
                }
                .inspector(isPresented: $model.isInspectorPresented) {
                    inspector
                        .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width in
                            if model.isInspectorPresented, (280 ... 480).contains(width) {
                                inspectorWidth = width
                            }
                        }
                        .inspectorColumnWidth(min: 280, ideal: 340, max: 480)
                }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private extension WorkspaceView {
    @ToolbarContentBuilder
    private var canvasToolbar: some ToolbarContent {
        if #available(macOS 26, *) {
            workspaceTabsToolbarItem.sharedBackgroundVisibility(.hidden)
        } else {
            workspaceTabsToolbarItem
        }
        ToolbarItem(placement: .automatic) {
            Spacer()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if model.route != .issues {
                Button("Search", systemImage: "magnifyingglass") {
                    model.beginSearch()
                }
                .help("Search Tasks (Command-F)")
                Button("New Task", systemImage: "plus") {
                    model.beginQuickCapture()
                }
                .help("New Task (Command-N)")
                TaskViewOptionsMenu(model: model)
            }
        }
        if model.isInspectorPresented {
            if #available(macOS 26, *) {
                inspectorToolbarSpace.sharedBackgroundVisibility(.hidden)
            } else {
                inspectorToolbarSpace
            }
        }
        ToolbarItem(id: "taskmark.inspector-toggle", placement: .primaryAction) {
            inspectorToggle
        }
    }

    private var workspaceTabsToolbarItem: some ToolbarContent {
        ToolbarItem(id: "taskmark.workspace-tabs", placement: .navigation) {
            WorkspaceTabBar(
                model: model,
                tabs: tabState.tabs,
                selection: tabState.selection,
                onSelect: selectTab,
                onClose: closeTab
            )
            .frame(width: workspaceTabBarWidth, height: 30)
            .padding(.leading, 96)
        }
    }

    private var workspaceTabBarWidth: CGFloat {
        guard !tabState.isEmpty else { return 1 }
        let preferred = tabState.tabs.reduce(CGFloat.zero) { width, tab in
            width + (tab.isTask ? 260 : 120)
        }
        return min(preferred, max(120, canvasWidth - 340))
    }

    private var inspectorToolbarSpace: some ToolbarContent {
        // Keep toolbar identity stable while the AppKit view updates its intrinsic width.
        ToolbarItem(id: "taskmark.inspector-space", placement: .primaryAction) {
            // The trailing native control and its margin already occupy 44 points.
            InspectorToolbarSpace(width: max(0, inspectorWidth - 44))
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: {
                if !$0 {
                    model.errorMessage = nil
                }
            }
        )
    }

    private var inspectorToggle: some View {
        Button(
            model.isInspectorPresented ? "Hide Inspector" : "Show Inspector",
            systemImage: "sidebar.trailing"
        ) {
            model.isInspectorPresented.toggle()
        }
        .help(model.isInspectorPresented ? "Hide Inspector" : "Show Inspector")
    }

    private var canvas: some View {
        ZStack {
            TaskListView(model: model, onOpenTaskInTab: openTaskInTab)
                .opacity(showsTaskList ? 1 : 0)
                .allowsHitTesting(showsTaskList)
                .accessibilityHidden(!showsTaskList)
            if model.route == .issues, !isTaskTab {
                IssueCenterView(model: model)
            }
            if case let .task(path)? = tabState.selection {
                if let draft = model.taskDrafts[path] {
                    TaskTabView(model: model, draft: draft)
                        .id(path)
                } else {
                    ContentUnavailableView(
                        "Task Unavailable",
                        systemImage: "doc.questionmark",
                        description: Text("The task is no longer available in this vault.")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if case let .task(path)? = tabState.selection, let draft = model.taskDrafts[path] {
            TaskTabOptionsView(model: model, draft: draft)
                .id(path)
                .themeSurface("--inspector-background")
        } else {
            InspectorContentView(model: model)
        }
    }

    private var isTaskTab: Bool {
        if case .task? = tabState.selection {
            true
        } else {
            false
        }
    }

    private var showsTaskList: Bool {
        !isTaskTab && model.route != .issues
    }

    private func navigate(to route: WorkspaceRoute) {
        if !tabState.isEmpty {
            tabState.navigate(to: route)
        }
    }

    private func openRouteInTab(_ route: WorkspaceRoute) {
        tabState.open(.route(route), preserving: .route(model.route))
        activate(.route(route))
    }

    private func openTaskInTab(_ path: VaultPath) {
        tabState.open(.task(path), preserving: .route(model.route))
        model.isInspectorPresented = true
        activate(.task(path))
    }

    private func selectTab(_ tab: WorkspaceTab) {
        tabState.select(tab)
        activate(tab)
    }

    private func closeTab(_ tab: WorkspaceTab) {
        tabState.close(tab)
        if let selection = tabState.selection {
            activate(selection)
        }
    }

    private func closeSelectedTab() {
        guard let selection = tabState.selection, tabState.tabs.count > 1 else { return }
        closeTab(selection)
    }

    private func activate(_ tab: WorkspaceTab) {
        switch tab {
        case let .route(route):
            model.selectTask(nil)
            model.route = route
        case let .task(path):
            model.selectTask(path)
        }
    }
}
