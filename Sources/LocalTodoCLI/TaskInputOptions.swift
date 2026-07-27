import ArgumentParser
import Foundation
import LocalTodoDomain

struct TaskInputOptions: ParsableArguments {
    @Option(help: "Task title.")
    var title: String

    @Option(help: "Workflow status.")
    var status = TaskStatus.inbox.rawValue

    @Option(help: "Priority: p1, p2, p3, or p4.")
    var priority: String?

    @Option(help: "Planned date in YYYY-MM-DD.")
    var scheduled: String?

    @Option(help: "Hard deadline in YYYY-MM-DD.")
    var deadline: String?

    @Option(help: "Project path.")
    var project: String?

    @Option(help: "Area path.")
    var area: String?

    @Option(name: .long, help: "Tag. Repeat for multiple tags.")
    var tag: [String] = []

    @Option(help: "Markdown body.")
    var body = ""

    @Option(name: .customLong("repeat-rule"), help: "Fixed recurrence rule, for example FREQ=WEEKLY;BYDAY=MO.")
    var repeatRule: String?

    @Option(name: .customLong("repeat-after"), help: "After-completion interval, for example P3D.")
    var repeatAfter: String?

    func task(at path: VaultPath, now: Date) throws -> TodoTask {
        let status = try CLIParsing.taskStatus(status)
        return try TodoTask(
            path: path,
            title: title,
            status: status,
            priority: CLIParsing.priority(priority),
            scheduled: CLIParsing.date(scheduled),
            deadline: CLIParsing.date(deadline),
            project: project.map(CLIParsing.path),
            area: area.map(CLIParsing.path),
            tags: tag,
            recurrence: CLIParsing.recurrence(rule: repeatRule, after: repeatAfter),
            body: body,
            createdAt: now,
            updatedAt: now,
            completedAt: status == .done ? now : nil
        )
    }
}
