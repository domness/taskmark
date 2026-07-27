import ArgumentParser
import LocalTodoMarkdown

struct ProjectShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Show a project.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        guard let project = try await context.snapshot().projects[path]?.value else {
            throw CLIError.message("Project not found: \(path.value)")
        }
        try CLIPrinter.entity(.project(project), context: context, command: "project show")
    }
}
