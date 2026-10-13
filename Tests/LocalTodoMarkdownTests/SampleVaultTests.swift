import Foundation
import LocalTodoDomain
@testable import LocalTodoMarkdown
import Testing

struct SampleVaultTests {
    @Test func sampleCoversDailyViewsWithValidReferencesAndCalendarDates() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let calendar = try londonCalendar()
        // The day before the spring DST transition exercises calendar-day arithmetic.
        let now = try #require(ISO8601DateFormatter().date(from: "2026-03-28T23:30:00Z"))
        _ = try await SampleVault(root: root).prepare(now: now, calendar: calendar)
        let store = VaultStore(root: root)
        let snapshot = try await store.snapshot()
        #expect(snapshot.diagnostics.isEmpty)
        #expect(snapshot.scanCompleteness == .complete)
        #expect(snapshot.configuration.timezone == "Europe/London")
        let tasks = snapshot.tasks.values.map(\.value)
        let today = try CalendarDate("2026-03-28")
        for scope in [TaskScope.today, .inbox, .next, .upcoming, .waiting, .someday] {
            #expect(!TaskQuery(scope: scope).results(from: tasks, today: today).isEmpty)
        }
        #expect(tasks.contains { $0.status == .done && $0.completedAt != nil })
        let picnic = try #require(tasks.first { $0.title == "Pack a picnic" })
        #expect(try picnic.scheduled == CalendarDate("2026-03-30"))
        #expect(try picnic.deadline == CalendarDate("2026-03-31"))
        let filters = try await store.savedFilters().filters
        #expect(filters.count == 1)
        #expect(filters[0].query.results(from: tasks, today: today).count == 6)
        #expect(tasks.filter { $0.recurrence != nil }.count == 2)
        #expect(tasks.contains { $0.body.contains("- [ ]") && $0.body.contains("- [x]") })
    }

    @Test func reopeningPreservesEditsDeletionsUnknownKeysAndDates() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let calendar = try londonCalendar()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sample = SampleVault(root: root)
        _ = try await sample.prepare(now: now, calendar: calendar)
        let edited = root.appendingPathComponent("Tasks/01 Start here.md")
        let deleted = root.appendingPathComponent("Tasks/02 Capture.md")
        let original = try String(contentsOf: edited, encoding: .utf8)
        let changed = original.replacingOccurrences(of: "type: task", with: "type: task\nmy_note: keep")
            + "\nMy own notes.\n"
        try Data(changed.utf8).write(to: edited)
        try FileManager.default.removeItem(at: deleted)
        _ = try await sample.prepare(now: now.addingTimeInterval(86400 * 30), calendar: calendar)
        #expect(try String(contentsOf: edited, encoding: .utf8) == changed)
        #expect(!FileManager.default.fileExists(atPath: deleted.path))
    }

    @Test(arguments: Array(1 ... 20))
    func failuresNeverPublishPartialSampleAndCanRetry(failureWrite: Int) async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let calendar = try londonCalendar()
        let fileSystem = FailingWriteFileSystem(base: FoundationVaultFileSystem(), failureWrite: failureWrite)
        await #expect(throws: (any Error).self) {
            try await SampleVault(root: root, fileSystem: fileSystem).prepare(now: Date(), calendar: calendar)
        }
        #expect(!fileSystem.exists(at: root))
        #expect(try fileSystem.contentsOfDirectory(at: root.deletingLastPathComponent()).isEmpty)
        _ = try await SampleVault(root: root).prepare(now: Date(), calendar: calendar)
        #expect(try await VaultStore(root: root).snapshot().diagnostics.isEmpty)
    }

    @Test func occupiedOrMalformedSampleIsNeverReinitialized() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("my-notes.md")
        try Data("Keep my notes".utf8).write(to: file)
        let calendar = try londonCalendar()
        await #expect(throws: (any Error).self) {
            try await SampleVault(root: root).prepare(now: Date(), calendar: calendar)
        }
        #expect(try String(contentsOf: file, encoding: .utf8) == "Keep my notes")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".config").path))
    }

    @Test func concurrentPreparationDoesNotReplaceThePublishedVault() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let calendar = try londonCalendar()
        let results = await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 2 {
                group.addTask {
                    do {
                        _ = try await SampleVault(root: root).prepare(now: Date(), calendar: calendar)
                        return true
                    } catch { return false }
                }
            }
            var successes = 0
            for await success in group where success {
                successes += 1
            }
            return successes
        }
        #expect(results >= 1)
        #expect(try await VaultStore(root: root).snapshot().tasks.count == 14)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.deletingLastPathComponent().path)
            == ["Sample Vault"])
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Sample Vault")
    }

    private func londonCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        return calendar
    }
}
