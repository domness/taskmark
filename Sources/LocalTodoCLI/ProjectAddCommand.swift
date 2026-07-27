import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct ProjectAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a project.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String
    @Option var title: String
    @Option var status = ProjectStatus.active.rawValue
    @Option var area: String?
    @Option(name: .long) var tag: [String] = []
    @Option var body = ""

    func run() async throws {
        let context = try CLIContext(options: global)
        let snapshot = try await context.snapshot()
        let project = try makeProject(now: Date())
        if let area = project.area, snapshot.areas[area] == nil {
            throw CLIError.message("Area not found: \(area.value)")
        }
        if !global.dryRun {
            _ = try await context.store.create(.project(project))
        }
        try CLIPrinter.entity(.project(project), context: context, command: "project add", dryRun: global.dryRun)
    }

    private func makeProject(now: Date) throws -> Project {
        guard let status = ProjectStatus(rawValue: status) else {
            throw CLIError.message("Invalid project status: \(status)")
        }
        return try Project(
            path: CLIParsing.path(path),
            title: title,
            status: status,
            area: area.map(CLIParsing.path),
            tags: tag,
            body: body,
            createdAt: now,
            updatedAt: now,
            completedAt: status == .done ? now : nil
        )
    }
}
