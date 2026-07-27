import SwiftUI

@main
struct LocalTodoApp: App {
    @State private var model = WorkspaceModel()

    var body: some Scene {
        WindowGroup {
            WorkspaceView(model: model)
                .task { await model.restoreVault() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") { model.beginQuickCapture() }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(model.snapshot == nil)
            }
            CommandMenu("Navigate") {
                Button("Command Palette") { model.isCommandPalettePresented = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Today") { model.route = .today }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Inbox") { model.route = .inbox }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Next") { model.route = .next }
                    .keyboardShortcut("3", modifiers: .command)
            }
        }
    }
}
