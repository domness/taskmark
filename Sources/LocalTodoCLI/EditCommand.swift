import ArgumentParser
import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct EditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "edit", abstract: "Edit a task.")

    @OptionGroup var global: GlobalOptions
    @Argument(help: "Exact task path.") var path: String
    @Option var title: String?
    @Option var status: String?
    @Option var priority: String?
    @Flag var clearPriority = false
    @Option var scheduled: String?
    @Flag var clearScheduled = false
    @Option var deadline: String?
    @Flag var clearDeadline = false
    @Option var project: String?
    @Flag var clearProject = false
    @Option var area: String?
    @Flag var clearArea = false
    @Option(name: .long) var tag: [String] = []
    @Flag var clearTags = false
    @Option var body: String?
    @Option(name: .customLong("repeat-rule")) var repeatRule: String?
    @Option(name: .customLong("repeat-after")) var repeatAfter: String?
    @Flag var clearRecurrence = false
    @Option(help: "Reset checkboxes on repeat: true or false.") var resetChecklistOnRepeat: Bool?

    func run() async throws {
        let context = try CLIContext(options: global)
        let path = try CLIParsing.path(path)
        let snapshot = try await context.snapshot()
        let record = try TaskCommandSupport.record(at: path, in: snapshot)
        let updated = try editedTask(record.value, context: context, snapshot: snapshot)
        try TaskCommandSupport.validateReferences(updated, in: snapshot)
        if !global.dryRun {
            _ = try await context.store.update(.task(updated), expectedRevision: record.revision)
        }
        try CLIPrinter.entity(.task(updated), context: context, command: "edit", dryRun: global.dryRun)
    }

    private func makePatch() throws -> TaskPatch {
        var patch = TaskPatch()
        if let title {
            patch.title = .set(title)
        }
        if let status {
            patch.status = try .set(CLIParsing.taskStatus(status))
        }
        if priority != nil || clearPriority {
            patch.priority = try .set(CLIParsing.priority(priority))
        }
        if scheduled != nil || clearScheduled {
            patch.scheduled = try .set(CLIParsing.date(scheduled))
        }
        if deadline != nil || clearDeadline {
            patch.deadline = try .set(CLIParsing.date(deadline))
        }
        if project != nil || clearProject {
            patch.project = try .set(project.map(CLIParsing.path))
        }
        if area != nil || clearArea {
            patch.area = try .set(area.map(CLIParsing.path))
        }
        if !tag.isEmpty || clearTags {
            patch.tags = .set(tag)
        }
        try applyRecurrence(to: &patch)
        if let body {
            patch.body = .set(body)
        }
        if let resetChecklistOnRepeat {
            patch.resetChecklistOnRepeat = .set(resetChecklistOnRepeat)
        }
        return patch
    }

    private func applyRecurrence(to patch: inout TaskPatch) throws {
        if repeatRule != nil || repeatAfter != nil || clearRecurrence {
            patch.recurrence = try .set(CLIParsing.recurrence(rule: repeatRule, after: repeatAfter))
        }
    }

    private func editedTask(_ task: TodoTask, context: CLIContext, snapshot: VaultSnapshot) throws -> TodoTask {
        let now = Date()
        var patch = try makePatch()
        let edited = try patch.applying(to: task, now: now)
        guard status == "done", task.status != .done, edited.recurrence != nil else { return edited }
        // Complete from the edited inputs while preserving the original eligibility state, just like the inspector.
        patch.status = .unchanged
        return try TaskTransition.complete(
            patch.applying(to: task, now: now), now: now,
            today: context.today(configuration: snapshot.configuration, now: now),
            calendar: context.calendar(configuration: snapshot.configuration)
        )
    }
}
