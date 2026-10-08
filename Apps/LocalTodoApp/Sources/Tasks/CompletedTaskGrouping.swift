import Foundation
import LocalTodoDomain

struct CompletedTaskGroup: Equatable {
    let date: CalendarDate
    let tasks: [TodoTask]
}

enum CompletedTaskGrouping {
    static func groups(_ tasks: [TodoTask], calendar: Calendar) -> [CompletedTaskGroup] {
        let dated = tasks.compactMap { task -> (CalendarDate, TodoTask)? in
            guard task.status == .done,
                  let completedAt = task.completedAt,
                  let date = try? CalendarDate(date: completedAt, calendar: calendar)
            else { return nil }
            return (date, task)
        }
        return Dictionary(grouping: dated, by: \.0)
            .map { date, values in
                CompletedTaskGroup(
                    date: date,
                    tasks: values.map(\.1).sorted {
                        if $0.completedAt != $1.completedAt {
                            return ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
                        }
                        return $0.path.value < $1.path.value
                    }
                )
            }
            .sorted { $0.date > $1.date }
    }
}
