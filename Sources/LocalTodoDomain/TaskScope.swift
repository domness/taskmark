public enum TaskScope: Hashable, Sendable {
    case all
    case today
    case inbox
    case next
    case project(VaultPath)
    case area(VaultPath)
    case tag(String)
    case priority(TaskPriority?)
}
