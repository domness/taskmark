import LocalTodoPresentation
import SwiftUI
import UniformTypeIdentifiers

struct MobileRootView: View {
    @Bindable var workspace: MobileWorkspace

    var body: some View {
        Group {
            if workspace.snapshot == nil {
                TaskmarkWelcomeView(
                    isLoading: workspace.isLoading,
                    openSample: { Task { await workspace.openSampleVault() } },
                    createVault: { workspace.requestCreate() },
                    openVault: { workspace.requestOpen() }
                )
            } else {
                MobileWorkspaceView(workspace: workspace)
            }
        }
        .modifier(MobileThemeModifier(workspace: workspace))
        .preferredColorScheme(workspace.preferredColorScheme)
        .fileImporter(
            isPresented: $workspace.isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            Task { await workspace.handlePickedFolder(result) }
        }
        .alert("Taskmark", isPresented: Binding(
            get: { workspace.errorMessage != nil },
            set: {
                if !$0 {
                    workspace.errorMessage = nil
                }
            }
        )) {
            Button("OK") { workspace.errorMessage = nil }
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }
}
