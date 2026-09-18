import Foundation
import LocalTodoMarkdown
import Testing

@Test func timezoneMutationPreservesUnknownManifestValuesAndRemovesSystemOverride() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let manifest = root.appendingPathComponent(LocalTodoSchema.manifestPath)
    try Data("schema: 2\ntimezone: Europe/London\ncustom:\n  tags: [one, two]\n".utf8).write(to: manifest)
    let store = VaultStore(root: root)
    let initial = try await store.configurationRecord()
    let updated = try await store.setTimezone("Asia/Tokyo", expectedRevision: initial.revision)
    #expect(updated.value.timezone == "Asia/Tokyo")
    let cleared = try await store.setTimezone(nil, expectedRevision: updated.revision)
    #expect(cleared.value.timezone == nil)
    let source = try String(contentsOf: manifest, encoding: .utf8)
    #expect(source.contains("custom:"))
    #expect(source.contains("one"))
    #expect(source.contains("two"))
    #expect(!source.contains("timezone:"))
}

@Test func timezoneMutationRejectsExternalChangesAndInvalidIdentifiers() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let original = try await store.configurationRecord()
    let updated = try await store.setTimezone("Asia/Tokyo", expectedRevision: original.revision)
    await #expect(throws: VaultConfigurationError.conflict) {
        try await store.setTimezone("America/New_York", expectedRevision: original.revision)
    }
    await #expect(throws: VaultStoreError.self) {
        try await store.setTimezone("Invalid/Timezone", expectedRevision: updated.revision)
    }
    #expect(try await store.configurationRecord() == updated)
}

@Test func timezoneMutationRejectsSymlinkAndMalformedManifest() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let manifest = root.appendingPathComponent(LocalTodoSchema.manifestPath)
    let store = VaultStore(root: root)
    let original = try await store.configurationRecord()
    let malformed = Data("schema: [malformed]\n".utf8)
    try malformed.write(to: manifest)
    await #expect(throws: (any Error).self) { try await store.configurationRecord() }
    #expect(try Data(contentsOf: manifest) == malformed)
    let outside = root.appendingPathComponent("other.yml")
    try malformed.write(to: outside)
    try FileManager.default.removeItem(at: manifest)
    try FileManager.default.createSymbolicLink(at: manifest, withDestinationURL: outside)
    await #expect(throws: VaultStoreError.self) {
        try await store.setTimezone("Asia/Tokyo", expectedRevision: original.revision)
    }
    #expect(try Data(contentsOf: outside) == malformed)
}
