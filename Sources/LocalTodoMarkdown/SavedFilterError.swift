import Foundation

public enum SavedFilterError: Error, Equatable, Sendable, LocalizedError {
    case conflict
    case invalidFormat(String)

    public var errorDescription: String? {
        switch self {
        case .conflict: "Saved filters changed on disk. Reload them before saving again."
        case let .invalidFormat(detail): "Invalid .config/filters.md: \(detail)"
        }
    }
}
