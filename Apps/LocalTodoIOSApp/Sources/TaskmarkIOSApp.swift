import SwiftUI

@main
struct TaskmarkIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var workspace = MobileWorkspace()

    var body: some Scene {
        WindowGroup {
            MobileRootView(workspace: workspace)
                .task {
                    if await workspace.prepareUITestVaultIfRequested() == false {
                        await workspace.restoreVault()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        workspace.resumeProviderObservation()
                    } else {
                        workspace.suspendProviderObservation()
                    }
                }
        }
    }
}
