public enum TaskView: String, CaseIterable, Sendable, Codable {
    case all, today, inbox, next, upcoming, waiting, someday

    public var scope: TaskScope {
        switch self {
        case .all: .all
        case .today: .today
        case .inbox: .inbox
        case .next: .next
        case .upcoming: .upcoming
        case .waiting: .waiting
        case .someday: .someday
        }
    }

    public init?(scope: TaskScope) {
        guard let value = Self.allCases.first(where: { $0.scope == scope }) else { return nil }
        self = value
    }
}
