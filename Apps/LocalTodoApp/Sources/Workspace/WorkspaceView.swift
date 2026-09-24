import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectorWidth: CGFloat = 340
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager

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
        .disabled(model.isSavingConfiguration)
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
    }

    private var navigation: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            Group {
                if model.route == .issues {
                    IssueCenterView(model: model)
                } else {
                    TaskListView(model: model)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .inspector(isPresented: $model.isInspectorPresented) {
                InspectorContentView(model: model)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width in
                        if model.isInspectorPresented, (280 ... 480).contains(width) {
                            inspectorWidth = width
                        }
                    }
                    .inspectorColumnWidth(min: 280, ideal: 340, max: 480)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { canvasToolbar }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    @ToolbarContentBuilder
    private var canvasToolbar: some ToolbarContent {
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

    private var inspectorToolbarSpace: some ToolbarContent {
        // NSToolbar caches a custom item's minimum width. Replace only the inert space
        // when the divider moves, so shrinking the inspector also moves the actions right.
        ToolbarItem(id: "taskmark.inspector-space.\(inspectorWidth)", placement: .primaryAction) {
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
}
