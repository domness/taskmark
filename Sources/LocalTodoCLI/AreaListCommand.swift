import ArgumentParser
import LocalTodoDomain
import LocalTodoMarkdown

struct AreaListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List areas.")

    @OptionGroup var global: GlobalOptions
    @Option var status: [String] = []
    @Flag var all = false
    @Option var tag: [String] = []

    func run() async throws {
        let context = try CLIContext(options: global)
        let snapshot = try await context.snapshot()
        let statuses = try requestedStatuses()
        let requiredTags = Set(tag)
        let areas = snapshot.areas.values.map(\.value).filter { area in
            statuses.contains(area.status) && requiredTags.isSubset(of: Set(area.tags))
        }.sorted { $0.path.value < $1.path.value }
        try CLIPrinter.list(areas.map(LocalTodoEntity.area), context: context, command: "area list")
    }

    private func requestedStatuses() throws -> Set<AreaStatus> {
        if all {
            return Set(AreaStatus.allCases)
        }
        if status.isEmpty {
            return [.active]
        }
        return try Set(status.map { value in
            guard let parsed = AreaStatus(rawValue: value) else {
                throw CLIError.message("Invalid area status: \(value)")
            }
            return parsed
        })
    }
}
