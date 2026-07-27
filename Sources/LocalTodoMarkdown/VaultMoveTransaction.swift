import Foundation

struct VaultMoveTransaction {
    let fileSystem: any VaultFileSystem

    func apply(sourceURL: URL, destinationURL: URL, writes: [URL: Data]) throws {
        let originals = try originals(sourceURL: sourceURL, writes: writes)
        do {
            for url in writes.keys.sorted(by: { $0.path < $1.path }) {
                guard let data = writes[url] else {
                    continue
                }
                try fileSystem.writeAtomically(data, to: url)
            }
            try fileSystem.remove(at: sourceURL)
        } catch {
            rollback(originals: originals, destinationURL: destinationURL)
            throw VaultStoreError.inputOutput(error.localizedDescription)
        }
    }

    private func originals(sourceURL: URL, writes: [URL: Data]) throws -> [URL: Data] {
        var originals = [URL: Data]()
        for url in writes.keys where fileSystem.exists(at: url) {
            originals[url] = try fileSystem.read(at: url)
        }
        originals[sourceURL] = try fileSystem.read(at: sourceURL)
        return originals
    }

    private func rollback(originals: [URL: Data], destinationURL: URL) {
        if fileSystem.exists(at: destinationURL), originals[destinationURL] == nil {
            try? fileSystem.remove(at: destinationURL)
        }
        for (url, data) in originals {
            try? fileSystem.writeAtomically(data, to: url)
        }
    }
}
