public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case inbox
    case next
    case waiting
    case someday
    case done
    case canceled
}
