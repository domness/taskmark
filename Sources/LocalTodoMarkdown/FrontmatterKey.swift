public enum FrontmatterKey: String, CaseIterable, Sendable {
    case type
    case title
    case status
    case priority
    case scheduled
    case deadline
    case project
    case area
    case tags
    case recurrence
    case resetChecklistOnRepeat = "reset_checklist_on_repeat"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case completedAt = "completed_at"
}
