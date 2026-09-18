public enum LocalTodoSchema {
    public static let currentVersion = 2
    public static let manifestPath = ".config/config.yml"
    public static let entityTypes = ["task", "project", "area"]
    public static let taskStatuses = ["inbox", "next", "waiting", "someday", "done", "canceled"]
    public static let priorities = ["p1", "p2", "p3", "p4"]
}
