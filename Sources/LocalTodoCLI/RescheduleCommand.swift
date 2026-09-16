import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct RescheduleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reschedule", abstract: "Move task dates together, preserving their calendar-day offset."
    )
    @OptionGroup var global: GlobalOptions
    @Argument var path: String
    @Option(help: "New anchor date in YYYY-MM-DD.") var to: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let snapshot = try await context.snapshot()
        let record = try TaskCommandSupport.record(at: CLIParsing.path(path), in: snapshot)
        let updated = try TaskTransition.reschedule(
            record.value, to: CalendarDate(to), now: Date(),
            calendar: context.calendar(configuration: snapshot.configuration)
        )
        if !global.dryRun, updated != record.value {
            _ = try await context.store.update(.task(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.task(updated), context: context, command: "reschedule", dryRun: global.dryRun)
    }
}
