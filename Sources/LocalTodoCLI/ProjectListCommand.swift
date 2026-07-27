import ArgumentParser
import LocalTodoDomain
import LocalTodoMarkdown

struct ProjectListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List projects.")

    @OptionGroup var global: GlobalOptions
    @Option var status: [String] = []
    @Flag var all = false
    @Option var area: String?
    @Option var tag: [String] = []

    func run() async throws {
        let context = try CLIContext(options: global)
        let snapshot = try await context.snapshot()
        let statuses = try requestedStatuses()
        let area = try area.map(CLIParsing.path)
        let requiredTags = Set(tag)
        let projects = snapshot.projects.values.map(\.value).filter { project in
            statuses.contains(project.status)
                && (area == nil || project.area == area)
                && requiredTags.isSubset(of: Set(project.tags))
        }.sorted { $0.path.value < $1.path.value }
        try CLIPrinter.list(projects.map(LocalTodoEntity.project), context: context, command: "project list")
    }

    private func requestedStatuses() throws -> Set<ProjectStatus> {
        if all {
            return Set(ProjectStatus.allCases)
        }
        if status.isEmpty {
            return [.active, .someday]
        }
        return try Set(status.map { value in
            guard let parsed = ProjectStatus(rawValue: value) else {
                throw CLIError.message("Invalid project status: \(value)")
            }
            return parsed
        })
    }
}
