# Run Your Day

Open or create a **dedicated task vault** in the macOS app. Tasks stay in individual Markdown files; everyday editing does not require YAML.

## Capture And Plan

- **Today** shows tasks scheduled or due today or earlier.
- **Upcoming** shows future scheduled dates or deadlines. A task with an overdue scheduled date and a future deadline can appear in both views.
- **Waiting** and **Someday** follow the task's status, including undated tasks.
- Capture in Today schedules today; Upcoming schedules tomorrow; Next, Waiting and Someday use their respective status. Project/area capture assigns that collection. Capture from search or filters goes to Inbox. The destination shown when capture opens is retained if you navigate before submitting.
- Select a task and use **Task → Reschedule Selected Task…** for an exact date. Reschedule moves scheduled and deadline dates together, preserving their signed calendar-day separation. For a deadline-only task, it moves the deadline; an undated task gains a scheduled date. To edit just one date, use its inspector control.
- **View Options → Sort** offers title, priority, scheduled date, deadline, newest created/updated, and exact file path. Missing dates/priorities sort last; ties use exact paths.

## Repeat And Checklists

Open **Repeat** in the task inspector. Choose a fixed schedule (frequency, interval and optional weekly weekdays) or an interval after completion.

Fixed completion follows the existing cadence until the next occurrence is after the completion day. After-completion recurrence starts its interval on that day in the vault timezone. Monthly/yearly recurrence retains calendar clamping; see [the file contract](FILE_FORMAT.md#recurrence).

Write checklist steps in Notes using Markdown checkboxes such as `- [ ] Draft outline`. Recognized steps appear as native checkboxes above Notes. Toggling a step changes only its marker. Code blocks and comments remain untouched; see [supported checklist syntax](FILE_FORMAT.md#body-checklists).

**Reset checklist on repeat** is per task and defaults off. When enabled, recurring completion unchecks recognized steps. Ordinary completion leaves notes unchanged.

## Projects

Choose a project in the sidebar to edit its title, status and notes in the inspector. If a task is selected, use **Edit Project** above the task list. Title edits do not rename or move files.

Complete/Reopen changes only the project, not its tasks. Someday, done and canceled projects appear under **Inactive Projects**, collapsed by default. An inactive project already assigned to a task remains visible in that task's inspector.

## Combined And Saved Filters

Choose **New Filter** or press **Command-Shift-F**. Combine a view, project/area, statuses, required tags, priorities, text and scheduled/deadline ranges. All dimensions must match; statuses/priorities are alternatives, and every selected tag is required. Enable **Include completed and canceled tasks** when reviewing finished work.

Results update as criteria change. Name the query and choose **Save Filter**. Select a saved filter in the sidebar and use **Edit Filter → Update Filter** to change it. A different, unused name saves a copy. Changing a saved filter's sort opens its working editor so the definition is updated intentionally.

Working criteria are temporary until explicitly saved. Named definitions live in `.localtodo/filters.md` and are shared with the CLI. If another client changes that file, local criteria remain available: **Use File Version** loads the saved definition; **Keep Working Filter** reloads other definitions and permits an explicit subsequent save. Malformed definitions and missing references are surfaced rather than repaired.

## Keyboard Reference

| Action | Shortcut |
| --- | --- |
| Capture / submit / cancel | Command-N / Return / Escape |
| Today / Inbox / Next | Command-1 / Command-2 / Command-3 |
| Upcoming / Waiting / Someday | Command-4 / Command-5 / Command-6 |
| Search / filter editor | Command-F / Command-Shift-F |
| Command palette | Command-K |
| Complete or reopen selection | Command-Return |
| Edit selected task | Command-E |
| Reschedule to an exact date | Command-D |
| Reschedule for today / tomorrow | Command-Shift-T / Command-Shift-D |
| Undo / redo | Command-Z / Command-Shift-Z |

The sidebar, lists, pickers, checkbox controls, text fields and date popovers use native keyboard-accessible controls. Live focus traversal and VoiceOver behavior have not yet been manually verified.

## Saving And Conflicts

Task and project drafts autosave, survive navigation, and are flushed before quitting. Invalid input, missing files, write failures and overlapping external changes retain drafts for correction or recovery. Non-overlapping edits rebase onto the file. Completion, checklist reset and rescheduling group their related changes for undo/redo. External file changes invalidate stale history.

The app never restores project/area file moves. iCloud validation, migration and a real-use pilot are outside this milestone's evidence.

## CLI Equivalents

```sh
localtodo list --view upcoming --sort deadline
localtodo list --view waiting --tag work --priority p1
localtodo reschedule Tasks/review.md --to 2026-09-20 --dry-run
localtodo filter save "Waiting work" --view waiting --tag work --sort priority
localtodo filter run "Waiting work"
localtodo filter delete "Waiting work" --dry-run
```

Run these inside the vault or supply `--vault PATH`. CLI mutations support `--dry-run`; the app and CLI share domain transitions and storage validation.

`edit --status done` also rolls recurring tasks forward, using all fields edited in that command. This intentionally changes the earlier status-only behavior. Remove recurrence in the same command (`--clear-recurrence --status done`) to finish permanently. `show --json` includes the recurrence mode, full `repeat_rule` or `repeat_after`, and checklist-reset preference.
