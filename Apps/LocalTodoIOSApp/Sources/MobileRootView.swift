import SwiftUI
import UniformTypeIdentifiers

struct MobileRootView: View {
    @Bindable var workspace: MobileWorkspace

    var body: some View {
        Group {
            if workspace.snapshot == nil {
                MobileOnboardingView(workspace: workspace)
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

private struct MobileOnboardingView: View {
    let workspace: MobileWorkspace

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Open Your Taskmark Vault", systemImage: "checkmark.circle")
            } description: {
                Text(
                    "Choose the same schema-2 folder you use on your Mac, or select an empty folder to create a vault."
                )
            } actions: {
                Button("Open Existing Vault") { workspace.requestOpen() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("open-vault")
                Button("Create Vault in Empty Folder") { workspace.requestCreate() }
                    .accessibilityIdentifier("create-vault")
            }
            .navigationTitle("Taskmark")
            .overlay {
                if workspace.isLoading {
                    ProgressView()
                }
            }
        }
    }
}
