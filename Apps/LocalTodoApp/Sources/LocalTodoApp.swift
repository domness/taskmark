import SwiftUI

@main
struct LocalTodoApp: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {}
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(true)
            }
        }
    }
}
