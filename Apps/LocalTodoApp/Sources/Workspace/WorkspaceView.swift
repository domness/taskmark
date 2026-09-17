import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var colorScheme

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
                } detail: {
                    if model.route == .issues {
                        IssueCenterView(model: model)
                    } else {
                        TaskListView(model: model)
                    }
                }
                .inspector(isPresented: $model.isInspectorPresented) {
                    InspectorContentView(model: model)
                        .inspectorColumnWidth(min: 280, ideal: 340, max: 480)
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .tint(model.effectiveAppearance.color("--accent", scheme: colorScheme, fallback: .accentColor))
        .sheet(isPresented: $model.isCommandPalettePresented) {
            CommandPaletteView(model: model)
        }
        .sheet(item: $model.newEntityKind) { kind in
            NewEntitySheet(model: model, kind: kind)
        }
        .sheet(item: $model.rescheduleSelection) { selection in
            TaskRescheduleSheet(model: model, selection: selection)
        }
        .alert("Local Todo", isPresented: errorPresented) {
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
}
