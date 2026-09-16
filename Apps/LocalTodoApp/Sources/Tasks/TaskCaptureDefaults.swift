import Foundation
import LocalTodoDomain

struct TaskCaptureDefaults {
    var status: TaskStatus = .inbox
    var scheduled: CalendarDate?
    var project: VaultPath?
    var area: VaultPath?
    var tags: [String] = []
    var priority: TaskPriority?

    init(route: WorkspaceRoute, today: CalendarDate, calendar: Calendar) throws {
        switch route {
        case .today: status = .next; scheduled = today
        case .upcoming: status = .next; scheduled = try today.adding(DateComponents(day: 1), calendar: calendar)
        case .next: status = .next
        case .waiting: status = .waiting
        case .someday: status = .someday
        case let .project(path): status = .next; project = path
        case let .area(path): status = .next; area = path
        case let .tag(tag): tags = [tag]
        case let .priority(value): priority = value
        default: break
        }
    }
}
