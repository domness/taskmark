import AppKit
import Foundation

@MainActor
enum VaultPicker {
    static func chooseDirectory() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Local Todo Vault"
        panel.message = "Select a folder containing .localtodo/config.yml."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        return await panel.begin() == .OK ? panel.url : nil
    }
}
