import Foundation

public extension FoundationVaultFileSystem {
    func coordinateMoving(
        from source: URL,
        to destination: URL,
        operation: (URL, URL) throws -> Void
    ) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(
            writingItemAt: source, options: .forMoving,
            writingItemAt: destination, options: .forReplacing,
            error: &coordinationError
        ) { sourceURL, destinationURL in
            do {
                try operation(sourceURL, destinationURL)
                coordinator.item(at: sourceURL, didMoveTo: destinationURL)
            } catch {
                operationError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }

    func coordinateWriting(
        at url: URL,
        intent: VaultWriteIntent,
        operation: (URL) throws -> Void
    ) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        let options: NSFileCoordinator.WritingOptions = switch intent {
        case .replacing: .forReplacing
        case .deleting: .forDeleting
        }
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { coordinatedURL in
            do {
                try operation(coordinatedURL)
            } catch {
                operationError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }
}
