import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.snapshot == nil {
                ContentUnavailableView {
                    Label("Choose a Vault", systemImage: "folder")
                } description: {
                    Text("Open a folder containing .localtodo/config.yml.")
                } actions: {
                    Button("Choose Vault") { Task { await model.chooseVault() } }
                        .keyboardShortcut(.defaultAction)
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
        .sheet(isPresented: $model.isCommandPalettePresented) {
            CommandPaletteView(model: model)
        }
        .sheet(item: $model.newEntityKind) { kind in
            NewEntitySheet(model: model, kind: kind)
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
