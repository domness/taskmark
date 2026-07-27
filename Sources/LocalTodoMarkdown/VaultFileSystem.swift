import Foundation

public protocol VaultFileSystem: Sendable {
    func createDirectory(at url: URL) throws
    func exists(at url: URL) -> Bool
    func markdownFiles(in root: URL) throws -> [URL]
    func move(from source: URL, to destination: URL) throws
    func read(at url: URL) throws -> Data
    func remove(at url: URL) throws
    func writeAtomically(_ data: Data, to url: URL) throws
}
