import ArgumentParser
import LocalTodoMarkdown

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: "Search tasks.")

    @OptionGroup var global: GlobalOptions
    @Argument(help: "Case-insensitive search text.") var query: String
    @OptionGroup var filters: TaskQueryOptions

    func validate() throws {
        if query.isEmpty {
            throw ValidationError("Search query cannot be empty")
        }
    }

    func run() async throws {
        let context = try CLIContext(options: global)
        let snapshot = try await context.snapshot()
        let today = try context.today(configuration: snapshot.configuration)
        let tasks = try filters.query(text: query).results(from: snapshot.tasks.values.map(\.value), today: today)
        try CLIPrinter.list(tasks.map(LocalTodoEntity.task), context: context, command: "search")
    }
}
