import ArgumentParser
import LocalTodoMarkdown

struct AreaShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Show an area.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        guard let area = try await context.snapshot().areas[path]?.value else {
            throw CLIError.message("Area not found: \(path.value)")
        }
        try CLIPrinter.entity(.area(area), context: context, command: "area show")
    }
}
