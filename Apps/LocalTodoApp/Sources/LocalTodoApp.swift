import SwiftUI

@main
struct LocalTodoApp: App {
    @NSApplicationDelegateAdaptor(LocalTodoAppDelegate.self) private var appDelegate
    @State private var model = WorkspaceModel()

    var body: some Scene {
        WindowGroup {
            WorkspaceView(model: model)
                .onAppear { appDelegate.model = model }
                .task { await model.restoreVault() }
        }
        .commands {
            DailyTaskCommands(model: model)
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.performUndo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!model.canPerformHistory)
                Button("Redo") { model.performRedo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!model.canPerformHistory)
            }
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
                Button("Upcoming") { model.route = .upcoming }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Waiting") { model.route = .waiting }
                    .keyboardShortcut("5", modifiers: .command)
                Button("Someday") { model.route = .someday }
                    .keyboardShortcut("6", modifiers: .command)
                Button("Filter Tasks") { model.beginFilterEditing() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Search Tasks") { model.beginSearch() }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
