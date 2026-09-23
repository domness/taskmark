import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
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
                NavigationSplitView {
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
                            .inspectorColumnWidth(min: 280, ideal: 340, max: 480)
                            .toolbar {
                                ToolbarItem(id: "taskmark.inspector-toggle", placement: .primaryAction) {
                                    inspectorToggle
                                }
                            }
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
        Button(model.isInspectorPresented ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing") {
            model.isInspectorPresented.toggle()
        }
        .labelStyle(.iconOnly)
        .help(model.isInspectorPresented ? "Hide Inspector" : "Show Inspector")
    }
}
