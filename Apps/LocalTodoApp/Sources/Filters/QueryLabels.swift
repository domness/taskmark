import LocalTodoDomain

extension TaskSort {
    var title: String {
        switch self {
        case .path: "File Path"
        case .title: "Title"
        case .priority: "Priority, Highest First"
        case .scheduled: "Scheduled, Earliest First"
        case .deadline: "Deadline, Earliest First"
        case .created: "Created, Newest First"
        case .updated: "Updated, Newest First"
        }
    }
}

extension TaskView {
    var title: String {
        self == .all ? "All Tasks" : rawValue.capitalized
    }
}
