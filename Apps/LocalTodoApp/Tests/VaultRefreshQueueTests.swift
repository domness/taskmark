import Foundation
@testable import LocalTodoApp
import Testing

@MainActor
struct VaultRefreshQueueTests {
    @Test func concurrentRequestsProduceOneFollowUpWithoutOverlapping() async throws {
        let queue = VaultRefreshQueue()
        let gate = RefreshGate()
        var calls = 0
        var active = 0
        var maximumActive = 0
        let first = Task {
            await queue.run {
                calls += 1
                active += 1
                maximumActive = max(maximumActive, active)
                await gate.wait()
                active -= 1
            }
        }
        try await waitForRefreshCondition { gate.continuation != nil }
        var submitted = 0
        let followers = (0 ..< 20).map { _ in
            Task {
                submitted += 1
                await queue.run {
                    calls += 1
                    active += 1
                    maximumActive = max(maximumActive, active)
                    active -= 1
                }
            }
        }
        try await waitForRefreshCondition { submitted == 20 }
        gate.resume()
        await first.value
        for follower in followers {
            await follower.value
        }
        #expect(calls == 2)
        #expect(maximumActive == 1)
        await queue.run { calls += 1 }
        #expect(calls == 3)
    }

    @Test func cancelDropsPendingWorkAndOldCompletionDoesNotClearNewWork() async throws {
        let queue = VaultRefreshQueue()
        let oldGate = RefreshGate()
        let newGate = RefreshGate()
        var staleRan = false
        let first = Task { await queue.run { await oldGate.wait() } }
        try await waitForRefreshCondition { oldGate.continuation != nil }
        var submitted = false
        let stale = Task {
            submitted = true
            await queue.run { staleRan = true }
        }
        try await waitForRefreshCondition { submitted }
        queue.cancel()
        let replacement = Task { await queue.run { await newGate.wait() } }
        try await waitForRefreshCondition { newGate.continuation != nil }
        oldGate.resume()
        await first.value
        await stale.value
        #expect(!staleRan)
        var followUpRan = false
        let followUp = Task { await queue.run { followUpRan = true } }
        await Task.yield()
        #expect(!followUpRan)
        newGate.resume()
        await replacement.value
        await followUp.value
        #expect(followUpRan)
    }
}

@MainActor
private final class RefreshGate {
    var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
func waitForRefreshCondition(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(8))
    while !condition(), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(20))
    }
    try #require(condition())
}
