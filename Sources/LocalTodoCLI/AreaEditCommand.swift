import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct AreaEditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "edit", abstract: "Edit an area.")

    @OptionGroup var global: GlobalOptions
    @Argument var path: String
    @Option var title: String?
    @Option var status: String?
    @Option(name: .long) var tag: [String] = []
    @Flag var clearTags = false
    @Option var body: String?

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        guard let record = snapshot.areas[path] else {
            throw CLIError.message("Area not found: \(path.value)")
        }
        let updated = try makePatch().applying(to: record.value, now: Date())
        if !global.dryRun {
            _ = try await context.store.update(.area(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.area(updated), context: context, command: "area edit", dryRun: global.dryRun)
    }

    private func makePatch() throws -> AreaPatch {
        var patch = AreaPatch()
        if let title {
            patch.title = .set(title)
        }
        if let status {
            guard let status = AreaStatus(rawValue: status) else {
                throw CLIError.message("Invalid area status: \(status)")
            }
            patch.status = .set(status)
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
