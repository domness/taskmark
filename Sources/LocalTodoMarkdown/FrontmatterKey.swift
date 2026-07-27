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
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case completedAt = "completed_at"
}
