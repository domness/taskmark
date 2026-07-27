import Foundation
import LocalTodoMarkdown

func makeCLITestVault() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-cli-tests-\(UUID().uuidString)")
    try VaultInitializer.initialize(at: root, timezone: "Europe/London")
    let fileSystem = FoundationVaultFileSystem()
    try fileSystem.createDirectory(at: root.appendingPathComponent("Tasks"))
    try fileSystem.createDirectory(at: root.appendingPathComponent("Projects"))
    try fileSystem.createDirectory(at: root.appendingPathComponent("Areas"))
    return root
}

func removeCLITestVault(_ root: URL) {
    try? FileManager.default.removeItem(at: root)
}
