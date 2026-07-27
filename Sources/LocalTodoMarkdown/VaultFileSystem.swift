import Foundation

public enum VaultWriteIntent: Equatable, Sendable {
    case replacing
    case deleting
}

public protocol VaultFileSystem: Sendable {
    func coordinateWriting(
        at url: URL,
        intent: VaultWriteIntent,
        operation: (URL) throws -> Void
    ) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func createDirectory(at url: URL) throws
    func exists(at url: URL) -> Bool
    func markdownFiles(in root: URL) throws -> [URL]
    func move(from source: URL, to destination: URL) throws
    func read(at url: URL) throws -> Data
    func remove(at url: URL) throws
    func removeEmptyDirectory(at url: URL) throws
    func removeFile(at url: URL) throws
    func writeAtomically(_ data: Data, to url: URL) throws
    func writeExclusively(_ data: Data, to url: URL) throws
}
