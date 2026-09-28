import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func coordinatedReadsAndExclusiveCreationUseExactURLs() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let fileSystem = ProviderTestFileSystem()
    let store = VaultStore(root: root, fileSystem: fileSystem)
    let task = try testTask(path: "Tasks/Coordinated.md")

    _ = try await store.create(.task(task))
    _ = try await store.snapshot()

    #expect(fileSystem.writeIntents.contains(.creating))
    #expect(fileSystem.coordinatedReadCount >= 2)
}

@Test func partialProviderScanRetainsLastKnownRecordsAsUnavailable() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let fileSystem = ProviderTestFileSystem()
    let store = VaultStore(root: root, fileSystem: fileSystem)
    let task = try testTask(path: "Tasks/Retained.md")
    _ = try await store.create(.task(task))
    fileSystem.versions = [task.path.value: [providerVersion(id: "retained-version", text: "alternative")]]
    let complete = try await store.snapshot()
    #expect(complete.scanCompleteness == .complete)
    #expect(complete.providerConflicts[task.path.value] != nil)

    fileSystem.failEnumeration = true
    let partial = try await store.snapshot()

    #expect(partial.tasks[task.path]?.value == task)
    #expect(partial.scanCompleteness != .complete)
    #expect(partial.availability[task.path] == .unavailable("Not returned by an incomplete provider scan"))
    #expect(partial.providerConflicts[task.path.value] != nil)
}

@Test func downloadPendingEntityProducesPartialSnapshotWithoutInventingContent() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let task = try testTask(path: "Tasks/Pending.md")
    _ = try await VaultStore(root: root).create(.task(task))
    let fileSystem = ProviderTestFileSystem()
    fileSystem.pendingPath = task.path.value

    let snapshot = try VaultScanner(root: root, fileSystem: fileSystem).scan()

    #expect(snapshot.tasks[task.path] == nil)
    #expect(snapshot.availability[task.path] == .downloading)
    #expect(snapshot.scanCompleteness != .complete)
    #expect(fileSystem.materializationRequests.contains { $0.hasSuffix(task.path.value) })
}

@Test func failedMaterializationRequestIsReportedAsUnavailable() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let task = try testTask(path: "Tasks/Unavailable.md")
    _ = try await VaultStore(root: root).create(.task(task))
    let fileSystem = ProviderTestFileSystem()
    fileSystem.pendingPath = task.path.value
    fileSystem.materializationError = VaultStoreError.inputOutput("iCloud request failed")

    let snapshot = try VaultScanner(root: root, fileSystem: fileSystem).scan()

    #expect(snapshot.tasks[task.path] == nil)
    guard case let .unavailable(message) = snapshot.availability[task.path] else {
        Issue.record("Expected a failed download request to make the task unavailable")
        return
    }
    #expect(message.contains("iCloud request failed"))
    #expect(snapshot.diagnostics.contains { $0.path == task.path && $0.message.contains("iCloud request failed") })
}

@Test func providerConflictsIncludeEntitiesAndConfigurationMetadata() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let task = try testTask(path: "Tasks/Conflict.md")
    _ = try await VaultStore(root: root).create(.task(task))
    let fileSystem = ProviderTestFileSystem()
    fileSystem.versions = [
        task.path.value: [providerVersion(id: "task-alternative", text: "task alternative")],
        LocalTodoSchema.manifestPath: [providerVersion(id: "config-alternative", text: "config alternative")],
    ]

    let snapshot = try VaultScanner(root: root, fileSystem: fileSystem).scan()

    #expect(snapshot.providerConflicts[task.path.value]?.alternatives.map(\.id) == ["task-alternative"])
    #expect(snapshot.providerConflicts[LocalTodoSchema.manifestPath]?.alternatives.map(\.id) == ["config-alternative"])
}

@Test func providerResolutionRevalidatesVersionSetBeforeWriting() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let task = try testTask(path: "Tasks/Racing.md")
    let canonical = try await VaultStore(root: root).create(.task(task))
    let fileSystem = ProviderTestFileSystem()
    fileSystem.versions = [task.path.value: [providerVersion(id: "first", text: "alternative")]]
    let store = VaultStore(root: root, fileSystem: fileSystem)
    let conflict = try #require(try await store.snapshot().providerConflicts[task.path.value])
    fileSystem.versions[task.path.value] = [
        providerVersion(id: "first", text: "alternative"),
        providerVersion(id: "racing", text: "racing alternative"),
    ]

    await #expect(throws: VaultStoreError.providerConflictChanged(task.path.value)) {
        try await store.resolveProviderConflict(
            at: task.path.value,
            choosing: Data("chosen".utf8),
            expectedCurrentRevision: conflict.currentRevision,
            expectedVersionIdentifiers: Set(conflict.alternatives.map(\.id))
        )
    }

    let persisted = try Data(contentsOf: root.appendingPathComponent(task.path.value))
    #expect(FileRevision(data: persisted) == canonical.revision)
    #expect(fileSystem.resolvedIdentifiers.isEmpty)
}

@Test func providerResolutionPersistsChosenBytesThenMarksOnlyReviewedVersions() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let task = try testTask(path: "Tasks/Resolved.md")
    _ = try await VaultStore(root: root).create(.task(task))
    let chosen = Data("recover exact alternative bytes".utf8)
    let fileSystem = ProviderTestFileSystem()
    fileSystem.versions = [
        task.path.value: [
            VaultProviderVersion(id: "reviewed", modifiedAt: nil, localizedName: nil, content: chosen),
        ],
    ]
    let store = VaultStore(root: root, fileSystem: fileSystem)
    let conflict = try #require(try await store.snapshot().providerConflicts[task.path.value])

    try await store.resolveProviderConflict(
        at: conflict.path,
        choosing: chosen,
        expectedCurrentRevision: conflict.currentRevision,
        expectedVersionIdentifiers: Set(conflict.alternatives.map(\.id))
    )

    #expect(try Data(contentsOf: root.appendingPathComponent(task.path.value)) == chosen)
    #expect(fileSystem.resolvedIdentifiers == ["reviewed"])
}

private func providerVersion(id: String, text: String) -> VaultProviderVersion {
    VaultProviderVersion(id: id, modifiedAt: nil, localizedName: nil, content: Data(text.utf8))
}

private final class ProviderTestFileSystem: VaultFileSystem, @unchecked Sendable {
    private let base = FoundationVaultFileSystem()
    private let lock = NSLock()
    private var _writeIntents = [VaultWriteIntent]()
    private var _coordinatedReadCount = 0
    private var _failEnumeration = false
    private var _pendingPath: String?
    private var _materializationRequests = [String]()
    private var _materializationError: Error?
    private var _versions = [String: [VaultProviderVersion]]()
    private var _resolvedIdentifiers = Set<String>()

    var writeIntents: [VaultWriteIntent] {
        lock.withLock { _writeIntents }
    }

    var coordinatedReadCount: Int {
        lock.withLock { _coordinatedReadCount }
    }

    var failEnumeration: Bool {
        get { lock.withLock { _failEnumeration } }
        set { lock.withLock { _failEnumeration = newValue } }
    }

    var pendingPath: String? {
        get { lock.withLock { _pendingPath } }
        set { lock.withLock { _pendingPath = newValue } }
    }

    var materializationRequests: [String] {
        lock.withLock { _materializationRequests }
    }

    var materializationError: Error? {
        get { lock.withLock { _materializationError } }
        set { lock.withLock { _materializationError = newValue } }
    }

    var versions: [String: [VaultProviderVersion]] {
        get { lock.withLock { _versions } }
        set { lock.withLock { _versions = newValue } }
    }

    var resolvedIdentifiers: Set<String> {
        lock.withLock { _resolvedIdentifiers }
    }

    func coordinateReading(at url: URL, operation: (URL) throws -> Void) throws {
        lock.withLock { _coordinatedReadCount += 1 }
        try operation(url)
    }

    func coordinateMoving(from source: URL, to destination: URL, operation: (URL, URL) throws -> Void) throws {
        try operation(source, destination)
    }

    func coordinateWriting(at url: URL, intent: VaultWriteIntent, operation: (URL) throws -> Void) throws {
        lock.withLock { _writeIntents.append(intent) }
        try operation(url)
    }

    func availability(at url: URL) -> VaultItemAvailability {
        if let pendingPath, url.path.hasSuffix(pendingPath) {
            return .downloading
        }
        return base.availability(at: url)
    }

    func requestMaterialization(at url: URL) throws {
        let error = lock.withLock { () -> Error? in
            _materializationRequests.append(url.path)
            return _materializationError
        }
        if let error {
            throw error
        }
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try base.contentsOfDirectory(at: url)
    }

    func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
    }

    func exists(at url: URL) -> Bool {
        base.exists(at: url)
    }

    func isSymbolicLink(at url: URL) throws -> Bool {
        try base.isSymbolicLink(at: url)
    }

    func markdownFiles(in root: URL) throws -> [URL] {
        if failEnumeration {
            throw VaultStoreError.inputOutput("Provider listing unavailable")
        }
        return try base.markdownFiles(in: root)
    }

    func unresolvedProviderVersions(at url: URL) throws -> [VaultProviderVersion] {
        lock.withLock {
            _versions.first { url.path.hasSuffix($0.key) }?.value ?? []
        }
    }

    func markProviderVersionsResolved(at _: URL, identifiers: Set<String>) throws {
        lock.withLock { _resolvedIdentifiers.formUnion(identifiers) }
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
        try base.writeExclusively(data, to: url)
    }
}
