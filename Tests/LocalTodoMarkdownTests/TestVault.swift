import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

func makeTestVault() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("local-todo-tests-\(UUID().uuidString)")
    try VaultInitializer.initialize(at: root, timezone: "Europe/London")
    let fileSystem = FoundationVaultFileSystem()
    try fileSystem.createDirectory(at: root.appendingPathComponent("Tasks"))
    try fileSystem.createDirectory(at: root.appendingPathComponent("Projects"))
    try fileSystem.createDirectory(at: root.appendingPathComponent("Areas"))
    return root
}

func removeTestVault(_ root: URL) {
    try? FileManager.default.removeItem(at: root)
}

func testTask(
    path: String,
    project: VaultPath? = nil,
    area: VaultPath? = nil,
    title: String = "Test task"
) throws -> TodoTask {
    let timestamp = Date(timeIntervalSince1970: 1_774_608_000)
    return try TodoTask(
        path: VaultPath(path),
        title: title,
        status: .next,
        project: project,
        area: area,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func testProject(path: String, area: VaultPath? = nil) throws -> Project {
    let timestamp = Date(timeIntervalSince1970: 1_774_608_000)
    return try Project(
        path: VaultPath(path),
        title: "Test project",
        status: .active,
        area: area,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func testArea(path: String) throws -> Area {
    let timestamp = Date(timeIntervalSince1970: 1_774_608_000)
    return try Area(
        path: VaultPath(path),
        title: "Test area",
        status: .active,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}
