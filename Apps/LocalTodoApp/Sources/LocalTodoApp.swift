import SwiftUI

@main
struct LocalTodoApp: App {
    @NSApplicationDelegateAdaptor(LocalTodoAppDelegate.self) private var appDelegate
    @State private var windows = WorkspaceWindows()
    @State private var cliRegistration = CLIRegistration()
    @StateObject private var updates = AppUpdates()

    var body: some Scene {
        WindowGroup("Taskmark", id: "vault") {
            WorkspaceWindowRoot(windows: windows)
                .onAppear {
                    appDelegate.windows = windows
                    updates.start()
                    windows.startDockBadgeUpdates { NSApplication.shared.dockTile.badgeLabel = $0 }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 720)
        .commands {
            WorkspaceCommands(windows: windows)
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: updates.checkForUpdates)
                    .disabled(!updates.canCheckForUpdates)
            }
        }
        Settings {
            SettingsView(model: windows.settingsWorkspace, cliRegistration: cliRegistration, updates: updates)
                .modifier(AppAppearanceModifier(model: windows.settingsWorkspace))
                .disabled(windows.isFlushingAll || windows.settingsWorkspace.isClosingWindow)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 760, height: 620)
    }
}
