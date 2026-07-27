import ArgumentParser
import LocalTodoMarkdown

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List tasks.")

    @OptionGroup var global: GlobalOptions
    @OptionGroup var filters: TaskQueryOptions

    func run() async throws {
        let context = try CLIContext(options: global)
        let snapshot = try await context.snapshot()
        let today = try context.today(configuration: snapshot.configuration)
        let tasks = try filters.query().results(from: snapshot.tasks.values.map(\.value), today: today)
        try CLIPrinter.list(tasks.map(LocalTodoEntity.task), context: context, command: "list")
    }
}
