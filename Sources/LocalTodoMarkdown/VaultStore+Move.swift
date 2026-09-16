import Foundation
import LocalTodoDomain

public extension VaultStore {
    func validateMove(from source: VaultPath, to destination: VaultPath) throws {
        _ = try VaultScanner(root: root, fileSystem: fileSystem).loadConfiguration()
        try validateEntityPath(source)
        try validateEntityPath(destination)
        let sourceURL = fileURL(for: source)
        let destinationURL = fileURL(for: destination)
        guard fileSystem.exists(at: sourceURL) else {
            throw VaultStoreError.notFound(source)
        }
        guard !fileSystem.exists(at: destinationURL) else {
            throw VaultStoreError.destinationExists(destination)
        }
        guard fileSystem.exists(at: destinationURL.deletingLastPathComponent()) else {
            throw VaultStoreError.invalidVault("Destination parent directory does not exist")
        }
        let data = try performIO { try fileSystem.read(at: sourceURL) }
        let entity = try EntityDocumentCodec.decode(parseDocument(data, at: source), at: source)
        // Collection moves need a multi-file recovery design, not best-effort rollback.
        guard case .task = entity else {
            throw VaultStoreError.invalidVault(
                "Project and area moves are disabled until reference updates can be recovered safely; "
                    + "edit the title without changing the path instead"
            )
        }
    }

    func move(from source: VaultPath, to destination: VaultPath, now _: Date) throws -> VaultSnapshot {
        try validateMove(from: source, to: destination)
        let sourceURL = fileURL(for: source)
        let destinationURL = fileURL(for: destination)
        var didMove = false
        try performIO {
            try fileSystem
                .coordinateMoving(from: sourceURL, to: destinationURL) { coordinatedSource, coordinatedDestination in
                    guard coordinatedSource.standardizedFileURL.path == sourceURL.standardizedFileURL.path,
                          coordinatedDestination.standardizedFileURL.path == destinationURL.standardizedFileURL.path
                    else {
                        throw VaultStoreError.conflict(source)
                    }
                    try validateMove(from: source, to: destination)
                    try fileSystem.move(from: coordinatedSource, to: coordinatedDestination)
                    didMove = true
                }
        }
        guard didMove else {
            throw VaultStoreError.inputOutput("Coordinated move did not run")
        }
        do {
            return try snapshot()
        } catch {
            throw VaultStoreError.inputOutput(
                "Task moved successfully from \(source.value) to \(destination.value), "
                    + "but refreshing the vault failed. Do not retry the move; fix the vault and reload. "
                    + error.localizedDescription
            )
        }
    }
}
