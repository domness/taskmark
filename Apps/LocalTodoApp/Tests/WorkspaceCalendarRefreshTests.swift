import Foundation
@testable import LocalTodoApp
import LocalTodoDomain
import LocalTodoMarkdown
import Testing

@MainActor
struct WorkspaceCalendarRefreshTests {
    @Test func midnightTimerUpdatesPresentationWithoutScanningFiles() async throws {
        var now = try #require(ISO8601DateFormatter().date(from: "2026-10-14T22:59:59Z"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try VaultInitializer.initialize(at: root)
        let configuration = VaultConfiguration(timezone: "Europe/London")
        try Data(configuration.encoded().utf8).write(to: root.appendingPathComponent(LocalTodoSchema.manifestPath))
        let model = WorkspaceModel(clock: { now })
        defer {
            model.releaseWindowResources()
            try? FileManager.default.removeItem(at: root)
        }
        #expect(try await model.openVault(root))
        model.vaultObserver = nil
        model.lifecycleObserver = nil
        let store = try #require(model.store)
        let generation = try await store.snapshot().generation
        let previousDay = model.presentationDay
        now = now.addingTimeInterval(1)
        try await waitForRefreshCondition { model.presentationDay != previousDay }
        #expect(model.presentationDay == model.vaultCalendar.startOfDay(for: now))
        #expect(try await store.snapshot().generation == generation + 1)
    }

    @Test func presentationDayTracksDSTAndTimezoneChanges() throws {
        var now = try #require(ISO8601DateFormatter().date(from: "2026-10-25T00:30:00Z"))
        let model = WorkspaceModel(clock: { now })
        model.snapshot = emptySnapshot(timezone: "Europe/London")
        model.updatePresentationDay()
        let dayBeforeClocksChange = model.presentationDay
        now = now.addingTimeInterval(3600)
        model.updatePresentationDay()
        #expect(model.presentationDay == dayBeforeClocksChange)
        model.snapshot = emptySnapshot(timezone: "America/Los_Angeles")
        model.updatePresentationDay()
        #expect(model.presentationDay != dayBeforeClocksChange)
        #expect(try CalendarDate(date: model.presentationNow, calendar: model.vaultCalendar)
            .description == "2026-10-24")
    }

    private func emptySnapshot(timezone: String) -> VaultSnapshot {
        VaultSnapshot(
            generation: 1, configuration: VaultConfiguration(timezone: timezone),
            tasks: [:], projects: [:], areas: [:], diagnostics: []
        )
    }
}
