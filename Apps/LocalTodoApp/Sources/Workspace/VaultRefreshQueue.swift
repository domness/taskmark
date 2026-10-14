import Foundation

/// Serializes callers and collapses requests received during a scan into one follow-up.
@MainActor
final class VaultRefreshQueue {
    private var running: Task<Void, Never>?
    private var pending: (@MainActor () async -> Void)?
    private var generation = UUID()

    func run(_ operation: @escaping @MainActor () async -> Void) async {
        pending = operation
        if let running {
            await running.value
            return
        }
        let generation = generation
        let task = Task { [weak self] in
            while let self, self.generation == generation, !Task.isCancelled, let operation = pending {
                pending = nil
                await operation()
            }
            if let self, self.generation == generation {
                running = nil
            }
        }
        running = task
        await task.value
    }

    func cancel() {
        generation = UUID()
        pending = nil
        running?.cancel()
        running = nil
    }

    deinit {
        running?.cancel()
    }
}
