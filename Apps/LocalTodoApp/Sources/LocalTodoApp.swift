import SwiftUI

@main
struct LocalTodoApp: App {
    @NSApplicationDelegateAdaptor(LocalTodoAppDelegate.self) private var appDelegate
    @State private var windows = WorkspaceWindows()

    var body: some Scene {
        WindowGroup("Taskmark", id: "vault") {
            WorkspaceWindowRoot(windows: windows)
                .onAppear { appDelegate.windows = windows }
        }
        .commands {
            WorkspaceCommands(windows: windows)
        }
        Settings {
            SettingsView(model: windows.settingsWorkspace)
                .modifier(AppAppearanceModifier(model: windows.settingsWorkspace))
                .disabled(windows.isFlushingAll || windows.settingsWorkspace.isClosingWindow)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 760, height: 620)
    }
}
