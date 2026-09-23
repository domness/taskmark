import SwiftUI

@main
struct LocalTodoApp: App {
    @NSApplicationDelegateAdaptor(LocalTodoAppDelegate.self) private var appDelegate
    @State private var windows = WorkspaceWindows()
    @State private var cliRegistration = CLIRegistration()

    var body: some Scene {
        WindowGroup("Taskmark", id: "vault") {
            WorkspaceWindowRoot(windows: windows)
                .onAppear {
                    appDelegate.windows = windows
                    windows.startDockBadgeUpdates { NSApplication.shared.dockTile.badgeLabel = $0 }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 720)
        .commands {
            WorkspaceCommands(windows: windows)
        }
        Settings {
            SettingsView(model: windows.settingsWorkspace, cliRegistration: cliRegistration)
                .modifier(AppAppearanceModifier(model: windows.settingsWorkspace))
                .disabled(windows.isFlushingAll || windows.settingsWorkspace.isClosingWindow)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 760, height: 620)
    }
}
