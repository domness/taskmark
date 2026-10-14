import Foundation
import LocalTodoDomain

struct SampleVaultContent {
    let now: Date
    let calendar: Calendar
    let today: CalendarDate
    let personal = "Areas/Personal.md"
    let learning = "Projects/Getting Started.md"
    let weekend = "Projects/A Good Weekend.md"

    static func files(now: Date, calendar: Calendar) throws -> [(String, Data)] {
        let content = try Self(now: now, calendar: calendar, today: CalendarDate(date: now, calendar: calendar))
        let configuration = VaultConfiguration(
            timezone: calendar.timeZone.identifier,
            preferences: ["initial_view": .string("today")]
        )
        var files = try [(LocalTodoSchema.manifestPath, Data(configuration.encoded().utf8))]
        for entity in try content.entities() {
            try files.append((entity.path.value, Data(EntityDocumentCodec.encode(entity).rendered().utf8)))
        }
        var filters = TaskFilters()
        filters.tags = ["getting-started"]
        let guide = try SavedTaskFilter(name: "Getting started", query: TaskQuery(filters: filters))
        try files.append((
            VaultStore.savedFiltersPath,
            Data(SavedFilterDocumentCodec.encode([guide], preserving: nil).rendered().utf8)
        ))
        return files
    }

    private func entities() throws -> [LocalTodoEntity] {
        try collections() + guidedTasks() + organizationTasks() + everydayTasks() + deferredTasks() + repeatingTasks()
    }

    private func collections() throws -> [LocalTodoEntity] {
        try [
            .area(Area(
                path: VaultPath("Areas/Personal.md"),
                title: "Personal",
                status: .active,
                body: "An area groups ongoing parts of your life. This one holds your sample projects.\n",
                createdAt: now,
                updatedAt: now
            )),
            .project(Project(
                path: VaultPath("Projects/Getting Started.md"),
                title: "Getting Started",
                status: .active,
                area: VaultPath(personal),
                body: """
                # Welcome to your sample vault

                These are real, editable tasks. Your changes are saved here, separately from your own vault.
                Open the numbered tasks to learn the basics. You can edit, complete or delete any example.

                When you are ready, create a vault from the File menu on Mac, or Settings → Vault on iPhone/iPad.
                Choose an empty folder. To use an existing vault, choose Open Existing Vault or Switch Vault.
                For iCloud Drive, select the same complete vault folder on each device, including `.config`.
                Taskmark does not require an account or provide its own sync service.
                """,
                createdAt: now,
                updatedAt: now
            )),
            .project(Project(
                path: VaultPath("Projects/A Good Weekend.md"),
                title: "A Good Weekend",
                status: .active,
                area: VaultPath(personal),
                body: "A small project for a walk, a meal, and some time to recharge.\n",
                createdAt: now,
                updatedAt: now
            )),
        ]
    }

    private func guidedTasks() throws -> [LocalTodoEntity] {
        try [
            task("01 Start here", title: "1. Make yourself at home", day: 0, body: """
            # Your tasks. Your files.

            Welcome! This sample is a real vault: a folder of Markdown files, with no account needed.
            Everything here is safe to try. Your edits are saved between launches and stay separate from your own vault.

            Open the other numbered tasks in Getting Started for a short hands-on tour.
            Mark this task complete when you are ready. You can find it again in Completed.
            """),
            task("02 Capture", title: "2. Capture your first idea", day: 0, body: """
            Open Inbox and use the add-task button to write an idea. On Mac, you can also press Command-N.
            Give it a short title and save it. Organization can wait until you need it.

            Open your new task to add notes. Markdown supports **bold**, *emphasis*, and lists.
            """),
            task("03 Plan", title: "3. Plan something for Today", day: 0, body: """
            Open a task and set its Scheduled date to today. It will appear in Today.
            Use Deadline for a date it must be finished by. Change Scheduled to tomorrow to see it in Upcoming.

            A task can have both dates. Earlier incomplete tasks remain in Today so they are not forgotten.
            """),
            task("04 Checklist", title: "4. Break a task into small steps", day: 0, body: """
            Check off a step below, then try editing these notes. On iPhone/iPad, choose Edit Markdown.
            Add another line beginning with `- [ ]` to create a step of your own.

            - [x] Open this example
            - [ ] Check off a small step
            - [ ] Add a step in Markdown
            """),
        ]
    }

    private func organizationTasks() throws -> [LocalTodoEntity] {
        try [
            task("05 Organize", title: "5. Give your tasks a place", body: """
            Choose a Project to group tasks with a shared outcome, and an Area for an ongoing part of your life.
            Try assigning a task to A Good Weekend. Add a tag such as `outdoors`, or choose a priority.

            Find projects, areas, tags and priorities in the Mac sidebar or Browse on iPhone.
            The saved filter Getting started collects tasks with the `getting-started` tag.
            Search finds words in titles, notes and tags.
            """),
            task("06 Make it yours", title: "6. Make Taskmark yours", body: """
            Visit Settings to try a theme, change the start screen or choose how dates appear.
            View Options controls task sorting and grouping.

            Ready for your own tasks? On Mac, choose File → Create a Vault.
            On iPhone/iPad, open Settings → Vault → Create a Vault. Select an empty folder.
            You can reopen this sample from File → Open Sample Vault on Mac or Settings → Vault on iPhone/iPad.
            """),
        ]
    }
}

extension SampleVaultContent {
    private func everydayTasks() throws -> [LocalTodoEntity] {
        try [
            task(
                "A place to visit",
                title: "A place I would like to visit",
                status: .inbox,
                project: nil,
                tags: ["ideas"],
                body: "Capture first. Add a project, date or tag whenever it helps.\n"
            ),
            task(
                "Choose a walking route",
                title: "Choose a walking route",
                day: 1,
                priority: .p2,
                project: weekend,
                tags: ["outdoors"],
                body: "Look for a short loop with a good place to stop.\n"
            ),
            task(
                "Pack a picnic",
                title: "Pack a picnic",
                day: 2,
                deadlineDay: 3,
                priority: .p1,
                project: weekend,
                tags: ["outdoors"],
                body: "- [ ] Water\n- [ ] Sandwiches\n- [ ] A blanket\n"
            ),
        ]
    }

    private func deferredTasks() throws -> [LocalTodoEntity] {
        try [
            task(
                "Waiting for the forecast",
                title: "Check the weekend forecast",
                status: .waiting,
                project: weekend,
                tags: ["outdoors"],
                body: "Waiting keeps a task visible while the next step is on hold.\n"
            ),
            task(
                "Someday a longer hike",
                title: "Plan a longer hike",
                status: .someday,
                project: weekend,
                tags: ["ideas"],
                body: "Someday is a place for ideas you do not need to act on yet.\n"
            ),
        ]
    }

    private func repeatingTasks() throws -> [LocalTodoEntity] {
        try [
            task(
                "Weekly review",
                title: "Make a little space for next week",
                day: 1,
                recurrence: .fixed(FixedRecurrenceRule(frequency: .weekly)),
                project: learning,
                tags: ["routine"],
                body: """
                This repeats on a fixed weekly schedule. Complete it to advance its dates to the next occurrence.
                The same task stays in place. Its checklist resets because Reset Checklist is enabled.

                - [x] Review Inbox
                - [ ] Choose a next step
                """
            ),
            task(
                "Water the plants",
                title: "Water the plants",
                day: 2,
                recurrence: .afterCompletion(RecurrenceInterval(value: 3, unit: .day)),
                project: nil,
                tags: ["home"],
                body: "This repeats three days after you complete it. Try completing it and inspect the new date.\n"
            ),
            task(
                "Finished example",
                title: "Pick a notebook for ideas",
                status: .done,
                project: weekend,
                tags: ["home"],
                body: "Completed tasks remain in your vault. Reopen this one to try it again.\n"
            ),
        ]
    }

    private func task(
        _ filename: String, title: String, status: TaskStatus = .next, day: Int? = nil,
        deadlineDay: Int? = nil, priority: TaskPriority? = nil, recurrence: TaskRecurrence? = nil,
        project: String? = "Projects/Getting Started.md",
        tags: [String] = ["getting-started"], body: String
    ) throws -> LocalTodoEntity {
        try .task(TodoTask(
            path: VaultPath("Tasks/\(filename).md"), title: title, status: status, priority: priority,
            scheduled: day.map { try today.adding(DateComponents(day: $0), calendar: calendar) },
            deadline: deadlineDay.map { try today.adding(DateComponents(day: $0), calendar: calendar) },
            project: project.map(VaultPath.init), area: VaultPath(personal), tags: tags, recurrence: recurrence,
            resetChecklistOnRepeat: recurrence != nil, body: body + "\n",
            createdAt: now, updatedAt: now, completedAt: status == .done ? now : nil
        ))
    }
}
