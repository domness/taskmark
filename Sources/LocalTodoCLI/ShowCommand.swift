import ArgumentParser
import LocalTodoMarkdown

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Show an entity.")

    @OptionGroup var global: GlobalOptions
    @Argument(help: "Exact vault-relative path.") var path: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        let entity: LocalTodoEntity
        if let task = snapshot.tasks[path]?.value {
            entity = .task(task)
        } else if let project = snapshot.projects[path]?.value {
            entity = .project(project)
        } else if let area = snapshot.areas[path]?.value {
            entity = .area(area)
        } else {
            throw CLIError.message("Entity not found: \(path.value)")
        }
        try CLIPrinter.entity(entity, context: context, command: "show")
    }
}
