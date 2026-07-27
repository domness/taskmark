public enum Weekday: String, Codable, CaseIterable, Sendable {
    case monday = "MO"
    case tuesday = "TU"
    case wednesday = "WE"
    case thursday = "TH"
    case friday = "FR"
    case saturday = "SA"
    case sunday = "SU"

    init(calendarValue: Int) throws {
        guard let weekday = Self.allCases.first(where: { $0.calendarValue == calendarValue }) else {
            throw DomainValidationError.invalidRecurrenceRule
        }
        self = weekday
    }

    var calendarValue: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }
}
