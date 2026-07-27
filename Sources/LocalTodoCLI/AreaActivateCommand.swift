import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct AreaActivateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "activate", abstract: "Activate an area.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        guard let record = snapshot.areas[path] else {
            throw CLIError.message("Area not found: \(path.value)")
        }
        var patch = AreaPatch()
        patch.status = .set(.active)
        let updated = try patch.applying(to: record.value, now: Date())
        if !global.dryRun {
            _ = try await context.store.update(.area(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.area(updated), context: context, command: "area activate", dryRun: global.dryRun)
    }
}
