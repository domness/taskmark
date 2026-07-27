public enum FieldUpdate<Value: Sendable>: Sendable {
    case unchanged
    case set(Value)

    func resolve(_ current: Value) -> Value {
        switch self {
        case .unchanged: current
        case let .set(value): value
        }
    }
}

extension FieldUpdate: Equatable where Value: Equatable {}
