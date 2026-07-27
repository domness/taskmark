import LocalTodoDomain
import LocalTodoMarkdown

enum CLIParsing {
    static func path(_ value: String) throws -> VaultPath {
        do {
            return try VaultPath(value)
        } catch {
            throw CLIError.message("Invalid vault-relative Markdown path: \(value)")
        }
    }

    static func date(_ value: String?) throws -> CalendarDate? {
        guard let value else {
            return nil
        }
        do {
            return try CalendarDate(value)
        } catch {
            throw CLIError.message("Invalid date: \(value). Expected YYYY-MM-DD")
        }
    }

    static func taskStatus(_ value: String) throws -> TaskStatus {
        guard let status = TaskStatus(rawValue: value) else {
            throw CLIError.message("Invalid task status: \(value)")
        }
        return status
    }

    static func priority(_ value: String?) throws -> TaskPriority? {
        guard let value else {
            return nil
        }
        guard let priority = TaskPriority(rawValue: value) else {
            throw CLIError.message("Invalid priority: \(value)")
        }
        return priority
    }

    static func recurrence(rule: String?, after: String?) throws -> TaskRecurrence? {
        guard rule == nil || after == nil else {
            throw CLIError.message("Use either --repeat-rule or --repeat-after, not both")
        }
        do {
            if let rule {
                return try RecurrenceFormat.fixed(rule)
            }
            if let after {
                return try RecurrenceFormat.afterCompletion(after)
            }
            return nil
        } catch {
            throw CLIError.message("Invalid recurrence expression")
        }
    }
}
