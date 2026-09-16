import Foundation
import LocalTodoMarkdown

/// Injects write failure after real reads/coordination, without touching the original file.
struct WriteRejectingFileSystem: VaultFileSystem {
    private let base = FoundationVaultFileSystem()

    func coordinateMoving(from source: URL, to destination: URL, operation: (URL, URL) throws -> Void) throws {
        try base.coordinateMoving(from: source, to: destination, operation: operation)
    }

    func coordinateWriting(at url: URL, intent: VaultWriteIntent, operation: (URL) throws -> Void) throws {
        try base.coordinateWriting(at: url, intent: intent, operation: operation)
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
        try base.markdownFiles(in: root)
    }

    func move(from _: URL, to _: URL) throws {
        throw failure
    }

    func read(at url: URL) throws -> Data {
        try base.read(at: url)
    }

    func remove(at _: URL) throws {
        throw failure
    }

    func removeEmptyDirectory(at url: URL) throws {
        try base.removeEmptyDirectory(at: url)
    }

    func removeFile(at _: URL) throws {
        throw failure
    }

    func writeAtomically(_: Data, to _: URL) throws {
        throw failure
    }

    func writeExclusively(_: Data, to _: URL) throws {
        throw failure
    }

    private var failure: VaultStoreError {
        .inputOutput("Injected write failure")
    }
}
