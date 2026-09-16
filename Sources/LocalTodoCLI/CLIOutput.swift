import Foundation
import LocalTodoDomain
import LocalTodoMarkdown

struct CLIEnvelope<Data: Encodable>: Encodable {
    let apiVersion = 1
    let ok = true
    let command: String
    let dryRun: Bool
    let vault: String?
    let data: Data

    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version"
        case ok
        case command
        case dryRun = "dry_run"
        case vault
        case data
    }
}

struct EntityOutput: Encodable {
    let type: String
    let path: String
    let title: String
    let status: String
    let priority: String?
    let scheduled: String?
    let deadline: String?
    let project: String?
    let area: String?
    let tags: [String]
    let recurrence: String?
    let repeatRule: String?
    let repeatAfter: String?
    let resetChecklistOnRepeat: Bool?
    let body: String?
    let createdAt: String
    let updatedAt: String
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case type, path, title, status, priority, scheduled, deadline, project, area, tags, recurrence, body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case resetChecklistOnRepeat = "reset_checklist_on_repeat"
        case repeatRule = "repeat_rule"
        case repeatAfter = "repeat_after"
    }

    init(_ entity: LocalTodoEntity, includeBody: Bool) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        switch entity {
        case let .task(task):
            self.init(task: task, includeBody: includeBody, formatter: formatter)
        case let .project(project):
            self.init(project: project, includeBody: includeBody, formatter: formatter)
        case let .area(area):
            self.init(area: area, includeBody: includeBody, formatter: formatter)
        }
    }

    private init(task: TodoTask, includeBody: Bool, formatter: ISO8601DateFormatter) {
        type = "task"
        path = task.path.value
        title = task.title
        status = task.status.rawValue
        priority = task.priority?.rawValue
        scheduled = task.scheduled?.description
        deadline = task.deadline?.description
        project = task.project?.value
        area = task.area?.value
        tags = task.tags
        recurrence = task.recurrence.map(Self.recurrenceDescription)
        switch task.recurrence {
        case let .fixed(rule):
            repeatRule = RecurrenceFormat.expression(.fixed(rule))
            repeatAfter = nil
        case let .afterCompletion(interval):
            repeatRule = nil
            repeatAfter = RecurrenceFormat.expression(.afterCompletion(interval))
        case nil:
            repeatRule = nil
            repeatAfter = nil
        }
        resetChecklistOnRepeat = task.resetChecklistOnRepeat
        body = includeBody ? task.body : nil
        createdAt = formatter.string(from: task.createdAt)
        updatedAt = formatter.string(from: task.updatedAt)
        completedAt = task.completedAt.map(formatter.string)
    }

    private init(project value: Project, includeBody: Bool, formatter: ISO8601DateFormatter) {
        type = "project"
        path = value.path.value
        title = value.title
        status = value.status.rawValue
        priority = nil
        scheduled = nil
        deadline = nil
        project = nil
        area = value.area?.value
        tags = value.tags
        recurrence = nil
        repeatRule = nil
        repeatAfter = nil
        resetChecklistOnRepeat = nil
        body = includeBody ? value.body : nil
        createdAt = formatter.string(from: value.createdAt)
        updatedAt = formatter.string(from: value.updatedAt)
        completedAt = value.completedAt.map(formatter.string)
    }

    private init(area value: Area, includeBody: Bool, formatter: ISO8601DateFormatter) {
        type = "area"
        path = value.path.value
        title = value.title
        status = value.status.rawValue
        priority = nil
        scheduled = nil
        deadline = nil
        project = nil
        area = nil
        tags = value.tags
        recurrence = nil
        repeatRule = nil
        repeatAfter = nil
        resetChecklistOnRepeat = nil
        body = includeBody ? value.body : nil
        createdAt = formatter.string(from: value.createdAt)
        updatedAt = formatter.string(from: value.updatedAt)
        completedAt = nil
    }

    private static func recurrenceDescription(_ recurrence: TaskRecurrence) -> String {
        switch recurrence {
        case .fixed: "fixed"
        case .afterCompletion: "after-completion"
        }
    }
}

struct ListOutput: Encodable {
    let items: [EntityOutput]
    let count: Int

    init(_ items: [EntityOutput]) {
        self.items = items
        count = items.count
    }
}

enum CLIPrinter {
    static func entity(_ entity: LocalTodoEntity, context: CLIContext, command: String, dryRun: Bool = false) throws {
        if context.options.json {
            try json(EntityOutput(entity, includeBody: true), context: context, command: command, dryRun: dryRun)
        } else {
            print("\(entity.path.value)\t\(EntityOutput(entity, includeBody: false).title)")
        }
    }

    static func list(_ entities: [LocalTodoEntity], context: CLIContext, command: String) throws {
        let items = entities.map { EntityOutput($0, includeBody: false) }
        if context.options.json {
            try json(ListOutput(items), context: context, command: command, dryRun: false)
        } else {
            for item in items {
                print("\(item.path)\t\(item.status)\t\(item.title)")
            }
        }
    }

    static func json(
        _ data: some Encodable,
        context: CLIContext,
        command: String,
        dryRun: Bool
    ) throws {
        let envelope = CLIEnvelope(command: command, dryRun: dryRun, vault: context.root.path, data: data)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let encoded = try encoder.encode(envelope)
        guard let output = String(data: encoded, encoding: .utf8) else {
            throw CLIError.message("Unable to encode JSON output")
        }
        print(output)
    }
}
