import AppKit
import Foundation

@MainActor
enum VaultPicker {
    static func chooseExistingVault() async -> URL? {
        await chooseDirectory(
            title: "Open Local Todo Vault",
            message: "Select a folder containing .localtodo/config.yml.",
            prompt: "Open Vault",
            canCreateDirectories: false
        )
    }

    static func chooseNewVaultDirectory() async -> URL? {
        await chooseDirectory(
            title: "Create Local Todo Vault",
            message: "Choose an empty folder, or create a new folder for your tasks.",
            prompt: "Create Vault",
            canCreateDirectories: true
        )
    }

    private static func chooseDirectory(
        title: String,
        message: String,
        prompt: String,
        canCreateDirectories: Bool
    ) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = canCreateDirectories
        return await panel.begin() == .OK ? panel.url : nil
    }
}
