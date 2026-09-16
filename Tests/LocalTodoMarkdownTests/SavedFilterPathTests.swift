import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func savedFiltersRejectSymlinksAndCoordinatorRemaps() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let target = root.appendingPathComponent("Unrelated.md")
    let bytes = Data("Do not change me".utf8)
    try bytes.write(to: target)
    let url = root.appendingPathComponent(VaultStore.savedFiltersPath)
    try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
    let store = VaultStore(root: root)
    await #expect(throws: VaultStoreError.self) { try await store.saveFilters([], expectedRevision: nil) }
    #expect(try Data(contentsOf: target) == bytes)
    try FileManager.default.removeItem(at: url)
    let remapped = VaultStore(root: root, fileSystem: FailingWriteFileSystem(
        base: FoundationVaultFileSystem(), failureWrite: 100, coordinatedURL: target
    ))
    await #expect(throws: SavedFilterError.conflict) { try await remapped.saveFilters([], expectedRevision: nil) }
    #expect(try Data(contentsOf: target) == bytes)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}
