import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct ProjectEditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "edit", abstract: "Edit a project.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String
    @Option var title: String?
    @Option var status: String?
    @Option var area: String?
    @Flag var clearArea = false
    @Option(name: .long) var tag: [String] = []
    @Flag var clearTags = false
    @Option var body: String?

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        guard let record = snapshot.projects[path] else {
            throw CLIError.message("Project not found: \(path.value)")
        }
        let updated = try makePatch().applying(to: record.value, now: Date())
        if let area = updated.area, snapshot.areas[area] == nil {
            throw CLIError.message("Area not found: \(area.value)")
        }
        if !global.dryRun {
            _ = try await context.store.update(.project(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.project(updated), context: context, command: "project edit", dryRun: global.dryRun)
    }

    private func makePatch() throws -> ProjectPatch {
        var patch = ProjectPatch()
        if let title {
            patch.title = .set(title)
        }
        if let status {
            guard let status = ProjectStatus(rawValue: status) else {
                throw CLIError.message("Invalid project status: \(status)")
            }
            patch.status = .set(status)
        }
        if area != nil || clearArea {
            patch.area = try .set(area.map(CLIParsing.path))
        }
        if !tag.isEmpty || clearTags {
            patch.tags = .set(tag)
        }
        if let body {
            patch.body = .set(body)
        }
        return patch
    }
}
