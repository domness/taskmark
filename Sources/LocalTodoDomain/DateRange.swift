public struct DateRange: Equatable, Sendable {
    public var start: CalendarDate?
    public var end: CalendarDate?

    public init(start: CalendarDate? = nil, end: CalendarDate? = nil) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: CalendarDate?) -> Bool {
        guard let date else {
            return false
        }
        if let start, date < start {
            return false
        }
        if let end, date > end {
            return false
        }
        return true
    }
}
