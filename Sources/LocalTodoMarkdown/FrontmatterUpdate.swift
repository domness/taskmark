public enum FrontmatterUpdate: Equatable, Sendable {
    case string(String)
    case strings([String])
    case null
    case remove
}
