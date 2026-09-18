import Foundation
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@Test func sharedPreferencesPreserveUnknownNestedConfiguration() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let url = root.appendingPathComponent(LocalTodoSchema.manifestPath)
    try Data("""
    schema: 2
    timezone: Europe/London
    plugin: {keep: [one, two]}
    preferences:
      theme: standard
      custom_plugin: {flag: untouched}
      views:
        inbox:
          showsProject: true
          showsArea: true
          showsTags: true
          grouping: none
          plugin: {layout: retained}
    """.utf8).write(to: url)
    let store = VaultStore(root: root)
    let original = try await store.configurationRecord()
    let saved = try await store.setPreferences([
        "theme": .string("forest"),
        "views": .object(["inbox": .object(["sort": .string("deadline")])]),
    ], expectedRevision: original.revision)
    #expect(saved.value.preferences["theme"] == .string("forest"))
    #expect(saved.value.preferences["custom_plugin"] == .object(["flag": .string("untouched")]))
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("retained"))
    #expect(text.contains("one"))
    #expect(try await store.configurationRecord() == saved)
    await #expect(throws: VaultConfigurationError.conflict) {
        try await store.setPreferences(["theme": .string("sand")], expectedRevision: original.revision)
    }
}

@Test(arguments: [
    ["theme": ConfigurationValue.string("unknown")],
    ["week_start": .integer(0)],
    ["vault_stylesheet": .array([])],
    ["views": .object(["inbox": .string("invalid")])],
    ["custom_order": .object(["inbox": .object(["isEnabled": .bool(true), "paths": .array([.string("../bad.md")])])])],
])
func invalidSharedPreferencesLeaveOriginalBytes(changes: [String: ConfigurationValue]) async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let store = VaultStore(root: root)
    let record = try await store.configurationRecord()
    let url = root.appendingPathComponent(LocalTodoSchema.manifestPath)
    let bytes = try Data(contentsOf: url)
    await #expect(throws: (any Error).self) {
        try await store.setPreferences(changes, expectedRevision: record.revision)
    }
    #expect(try Data(contentsOf: url) == bytes)
}

@Test func failedPreferenceReplacementPreservesConfiguration() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    let url = root.appendingPathComponent(LocalTodoSchema.manifestPath)
    let bytes = try Data(contentsOf: url)
    let store = VaultStore(
        root: root,
        fileSystem: FailingWriteFileSystem(base: FoundationVaultFileSystem(), failureWrite: 1)
    )
    let record = try await store.configurationRecord()
    await #expect(throws: (any Error).self) {
        try await store.setPreferences(["theme": .string("slate")], expectedRevision: record.revision)
    }
    #expect(try Data(contentsOf: url) == bytes)
}

@Test func configDirectoryIsCanonicalAndExcludedFromEntityScanning() async throws {
    let root = try makeTestVault()
    defer { removeTestVault(root) }
    #expect(LocalTodoSchema.currentVersion == 2)
    #expect(LocalTodoSchema.manifestPath == ".config/config.yml")
    #expect(VaultStore.savedFiltersPath == ".config/filters.md")
    try Data("---\ntype: task\n---\nmetadata".utf8).write(to: root.appendingPathComponent(".config/plugin.md"))
    #expect(try await VaultStore(root: root).snapshot().diagnostics.isEmpty)
    #expect(throws: DomainValidationError.self) { try VaultPath(".config/plugin.md") }
    let legacy = root.appendingPathComponent(".localtodo")
    try FileManager.default.moveItem(at: root.appendingPathComponent(".config"), to: legacy)
    await #expect(throws: VaultStoreError.self) { try await VaultStore(root: root).snapshot() }
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".config").path))
    #expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("config.yml").path))
}
