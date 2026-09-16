import ArgumentParser
import LocalTodoDomain
import LocalTodoMarkdown

struct FilterCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "filter", abstract: "Save and run named vault filters.",
        subcommands: [FilterListCommand.self, FilterSaveCommand.self, FilterRunCommand.self, FilterDeleteCommand.self]
    )
}

struct FilterListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List saved filter names.")
    @OptionGroup var global: GlobalOptions

    func run() async throws {
        let context = try CLIContext(options: global)
        let record = try await context.store.savedFilters()
        if global.json {
            try CLIPrinter.json(record.filters.map(\.name), context: context, command: "filter list", dryRun: false)
        } else {
            for filter in record.filters {
                print(filter.name)
            }
        }
    }
}

struct FilterSaveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "save", abstract: "Save a combined task filter.")
    @OptionGroup var global: GlobalOptions
    @OptionGroup var filters: TaskQueryOptions
    @Argument var name: String
    @Option var text = ""
    @Flag(help: "Replace an existing filter with this exact name.") var replace = false

    func run() async throws {
        let context = try CLIContext(options: global)
        let filter = try SavedTaskFilter(name: name, query: filters.query(text: text))
        let record = try await context.store.savedFilters()
        guard replace || !record.filters.contains(where: { $0.name == name }) else {
            throw CLIError.message("A filter named \(name) already exists. Use --replace to update it.")
        }
        let updated = record.filters.filter { $0.name != name } + [filter]
        if !global.dryRun {
            _ = try await context.store.saveFilters(updated, expectedRevision: record.revision)
        }
        if global.json {
            try CLIPrinter.json(["name": name], context: context, command: "filter save", dryRun: global.dryRun)
        } else {
            print(name)
        }
    }
}

struct FilterRunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Run a saved task filter.")
    @OptionGroup var global: GlobalOptions
    @Argument var name: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let record = try await context.store.savedFilters()
        guard let filter = record.filters.first(where: { $0.name == name }) else {
            throw CLIError.message("Saved filter not found: \(name)")
        }
        let snapshot = try await context.snapshot()
        let missingReferences = filter.missingReferences(
            projects: Set(snapshot.projects.keys), areas: Set(snapshot.areas.keys)
        )
        if let missing = missingReferences.first {
            throw VaultStoreError.missingReference(missing)
        }
        let today = try context.today(configuration: snapshot.configuration)
        let tasks = filter.query.results(from: snapshot.tasks.values.map(\.value), today: today)
        try CLIPrinter.list(tasks.map(LocalTodoEntity.task), context: context, command: "filter run")
    }
}

struct FilterDeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a saved filter, leaving tasks intact."
    )
    @OptionGroup var global: GlobalOptions
    @Argument var name: String

    func run() async throws {
        let context = try CLIContext(options: global)
        let record = try await context.store.savedFilters()
        guard record.filters.contains(where: { $0.name == name }) else {
            throw CLIError.message("Saved filter not found: \(name)")
        }
        let updated = record.filters.filter { $0.name != name }
        if !global.dryRun {
            _ = try await context.store.saveFilters(updated, expectedRevision: record.revision)
        }
        if global.json {
            try CLIPrinter.json(["name": name], context: context, command: "filter delete", dryRun: global.dryRun)
        } else {
            print(name)
        }
    }
}
