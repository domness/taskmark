import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Observation
import Synchronization
import Testing

@MainActor
struct IdleRefreshTests {
    @Test func unchangedRefreshKeepsPublishedSnapshotGeneration() async throws {
        try await withWorkspace { model, _ in
            await model.createTask(title: "Unchanged", vaultSession: model.vaultSession)
            let generation = try #require(model.snapshot?.generation)
            await model.refresh()
            await model.refresh()
            #expect(model.snapshot?.generation == generation)
        }
    }

    @Test func unchangedRefreshDoesNotInvalidatePresentation() async throws {
        try await withWorkspace { model, _ in
            let changes = Mutex(0)
            withObservationTracking {
                _ = model.snapshot
                _ = model.configurationSettings
                _ = model.vaultAppearance
                _ = model.filterState.record
                _ = model.preferences.values
                _ = model.sidebarOrders
                _ = model.taskCustomOrders
                _ = model.taskListDisplayOptionsByRoute
            } onChange: {
                changes.withLock { $0 += 1 }
            }
            await model.refresh()
            #expect(changes.withLock { $0 } == 0)
        }
    }

    @Test func idleWorkspaceDoesNotScanEveryTwoSeconds() async throws {
        try await withWorkspace { model, _ in
            model.startVaultObservation()
            // Let events from fixture creation drain before measuring a quiet interval.
            try await Task.sleep(for: .seconds(1))
            let store = try #require(model.store)
            let before = try await store.snapshot().generation
            try await Task.sleep(for: .seconds(3))
            let after = try await store.snapshot().generation
            #expect(after == before + 1)
        }
    }

    @Test func configurationUpdatePreservesPartialScanAndProviderState() async throws {
        try await withWorkspace { model, _ in
            let path = try VaultPath("Tasks/Pending.md")
            model.snapshot = VaultSnapshot(
                generation: 1, configuration: VaultConfiguration(), tasks: [:], projects: [:], areas: [:],
                diagnostics: [], scanCompleteness: .partial("Downloading"), availability: [path: .downloading]
            )
            let store = try #require(model.store)
            let record = try await store.configurationRecord()
            try model.receiveConfiguration(record)
            #expect(model.snapshot?.scanCompleteness == .partial("Downloading"))
            #expect(model.snapshot?.availability[path] == .downloading)
        }
    }
}
