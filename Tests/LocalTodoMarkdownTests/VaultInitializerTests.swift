import Foundation
import LocalTodoMarkdown
import Testing

@Test func initializerRejectsNonEmptyDirectoryWithoutWritingManifest() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-initializer-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("Existing content".utf8).write(to: root.appendingPathComponent("notes.md"))

    #expect(throws: VaultStoreError.invalidVault("Directory is not empty")) {
        try VaultInitializer.initialize(at: root)
    }
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(LocalTodoSchema.manifestPath).path))
}

@Test func initializerCleansUpAfterWriteFailureAndAllowsRetry() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-initializer-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let fileSystem = FailingInitializerFileSystem(behavior: .fail)

    #expect(throws: InitializerTestError.injectedFailure) {
        try VaultInitializer.initialize(at: root, fileSystem: fileSystem)
    }
    #expect(try fileSystem.contentsOfDirectory(at: root).isEmpty)

    try VaultInitializer.initialize(at: root)

    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(LocalTodoSchema.manifestPath).path))
}

@Test func initializerDoesNotOverwriteConcurrentlyCreatedManifest() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-initializer-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let fileSystem = FailingInitializerFileSystem(behavior: .createManifestBeforeWrite)
    let manifest = root.appendingPathComponent(LocalTodoSchema.manifestPath)

    #expect(throws: VaultStoreError.invalidVault("Manifest already exists")) {
        try VaultInitializer.initialize(at: root, fileSystem: fileSystem)
    }

    #expect(try String(contentsOf: manifest, encoding: .utf8) == FailingInitializerFileSystem.concurrentManifest)
}

@Test func initializerPreservesContentAddedDuringSetup() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-todo-initializer-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let fileSystem = FailingInitializerFileSystem(behavior: .createRootFileAfterMarker)
    let concurrentFile = root.appendingPathComponent("concurrent.md")

    #expect(throws: VaultStoreError.invalidVault("Directory changed during initialization")) {
        try VaultInitializer.initialize(at: root, fileSystem: fileSystem)
    }

    #expect(try String(contentsOf: concurrentFile, encoding: .utf8) == "Concurrent content")
    #expect(!fileSystem.exists(at: root.appendingPathComponent(LocalTodoSchema.manifestPath)))
}

private struct FailingInitializerFileSystem: VaultFileSystem {
    func coordinateMoving(
        from source: URL, to destination: URL, operation: (URL, URL) throws -> Void
    ) throws {
        try base.coordinateMoving(from: source, to: destination, operation: operation)
    }

    static let concurrentManifest = "schema: concurrent\n"

    private let base = FoundationVaultFileSystem()
    let behavior: Behavior

    enum Behavior {
        case fail
        case createManifestBeforeWrite
        case createRootFileAfterMarker
    }

    func coordinateWriting(
        at url: URL,
        intent: VaultWriteIntent,
        operation: (URL) throws -> Void
    ) throws {
        try base.coordinateWriting(at: url, intent: intent, operation: operation)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try base.contentsOfDirectory(at: url)
    }

    func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
        if behavior == .createRootFileAfterMarker, url.lastPathComponent == ".config" {
            try Data("Concurrent content".utf8)
                .write(to: url.deletingLastPathComponent().appendingPathComponent("concurrent.md"))
        }
    }

    func exists(at url: URL) -> Bool {
        base.exists(at: url)
    }

    func isSymbolicLink(at url: URL) throws -> Bool {
        try base.isSymbolicLink(at: url)
    }

    func markdownFiles(in root: URL) throws -> [URL] {
        try base.markdownFiles(in: root)
    }

    func move(from source: URL, to destination: URL) throws {
        try base.move(from: source, to: destination)
    }

    func read(at url: URL) throws -> Data {
        try base.read(at: url)
    }

    func remove(at url: URL) throws {
        try base.remove(at: url)
    }

    func removeEmptyDirectory(at url: URL) throws {
        try base.removeEmptyDirectory(at: url)
    }

    func removeFile(at url: URL) throws {
        try base.removeFile(at: url)
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        try base.writeAtomically(data, to: url)
    }

    func writeExclusively(_ data: Data, to url: URL) throws {
        switch behavior {
        case .fail:
            throw InitializerTestError.injectedFailure
        case .createManifestBeforeWrite:
            try base.writeExclusively(Data(Self.concurrentManifest.utf8), to: url)
            try base.writeExclusively(data, to: url)
        case .createRootFileAfterMarker:
            try base.writeExclusively(data, to: url)
        }
    }
}

private enum InitializerTestError: Error {
    case injectedFailure
}
