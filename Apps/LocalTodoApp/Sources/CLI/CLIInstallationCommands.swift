import AppKit
import SwiftUI

struct CLIInstallationCommands: Commands {
    @State private var isInstalling = false

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Install Command-Line Tool…") {
                Task { await install() }
            }
            .disabled(isInstalling)
        }
    }

    @MainActor
    private func install() async {
        isInstalling = true
        defer { isInstalling = false }
        let panel = NSSavePanel()
        panel.title = "Install Taskmark Command-Line Tool"
        panel.message = "Save taskmark in a writable folder on your shell’s PATH, such as ~/.local/bin. "
            + "Use Go to Folder (Shift-Command-G) to enter a path."
        panel.nameFieldStringValue = "taskmark"
        panel.canCreateDirectories = true
        panel.prompt = "Install"
        guard await panel.begin() == .OK, let destination = panel.url else { return }
        let scoped = destination.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                destination.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let source = CLIInstaller.bundledExecutable()
            try await Task.detached { try CLIInstaller.install(from: source, to: destination) }.value
            showResult(
                "Command-Line Tool Installed",
                message: "Installed at \(destination.path). "
                    + "Add its folder to your shell’s PATH if needed, then run taskmark --help. "
                    + "Install again after updating Taskmark to update the command."
            )
        } catch {
            showResult("Could Not Install Command-Line Tool", message: error.localizedDescription)
        }
    }

    @MainActor
    private func showResult(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
