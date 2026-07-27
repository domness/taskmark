import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct AreaAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add an area.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String
    @Option var title: String
    @Option var status = AreaStatus.active.rawValue
    @Option(name: .long) var tag: [String] = []
    @Option var body = ""

    func run() async throws {
        let context = try CLIContext(options: global)
        guard let status = AreaStatus(rawValue: status) else {
            throw CLIError.message("Invalid area status: \(status)")
        }
        let now = Date()
        let area = try Area(
            path: CLIParsing.path(path),
            title: title,
            status: status,
            tags: tag,
            body: body,
            createdAt: now,
            updatedAt: now
        )
        if !global.dryRun {
            _ = try await context.store.create(.area(area))
        }
        try CLIPrinter.entity(.area(area), context: context, command: "area add", dryRun: global.dryRun)
    }
}
