import Foundation

public enum TaskSort: String, CaseIterable, Codable, Sendable {
    case path
    case title
    case priority
    case scheduled
    case deadline
    case created
    case updated

    func precedes(_ lhs: TodoTask, _ rhs: TodoTask) -> Bool {
        let comparison: ComparisonResult = switch self {
        case .path: compare(lhs.path.value, rhs.path.value)
        case .title:
            lhs.title.compare(
                rhs.title,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
        case .priority: compareOptional(lhs.priority?.rawValue, rhs.priority?.rawValue)
        case .scheduled: compareOptional(lhs.scheduled, rhs.scheduled)
        case .deadline: compareOptional(lhs.deadline, rhs.deadline)
        case .created: compare(rhs.createdAt, lhs.createdAt)
        case .updated: compare(rhs.updatedAt, lhs.updatedAt)
        }
        return comparison == .orderedSame ? lhs.path.value < rhs.path.value : comparison == .orderedAscending
    }

    private func compare<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        lhs == rhs ? .orderedSame : lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func compareOptional<Value: Comparable>(_ lhs: Value?, _ rhs: Value?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): compare(lhs, rhs)
        case (nil, nil): .orderedSame
        case (nil, _): .orderedDescending
        case (_, nil): .orderedAscending
        }
    }
}
