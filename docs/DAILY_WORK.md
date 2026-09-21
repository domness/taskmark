# Daily Workflows

Open or create a **dedicated task vault** in the macOS app. Tasks stay in individual Markdown files; everyday editing does not require YAML.

## Multiple Vault Windows

Choose **File → New Vault Window** (`Command-Shift-N`) to open another independent window, then choose **Open Existing Vault** or **Create New Vault** there. Each window has its own vault, navigation, selection, drafts and Undo/Redo. **Switch Vault** changes only that window. Task/navigation commands follow the focused vault window; `Command-N` still captures a task.

Appearance/calendar-display preferences belong to each vault's `.config/config.yml`; different vaults can use different themes. Settings edits the most recently active vault window. Windows/machines opening the same vault reload its shared settings. Closing a window flushes pending document and preference edits; unresolved edits or unsubmitted capture text keep it open. Quitting checks all open workspaces. The first window at launch restores the most recently opened vault; additional windows start with the vault chooser. Restoring a full set of previous vault windows is not implemented.

## Capture And Plan

- **Inbox** appears above Today in the sidebar and contains incomplete tasks with Inbox status.
- **Today** shows tasks scheduled or due today or earlier.
- Incomplete tasks with a scheduled date or deadline **before today in the vault timezone** have a red title, red overdue date and an **Overdue** warning label. Dates today are not overdue; done/canceled tasks are not highlighted. Priority indicators retain their own colors.
- **Upcoming** shows future scheduled dates or deadlines. A task with an overdue scheduled date and a future deadline can appear in both views.
- **Waiting** and **Someday** follow the task's status, including undated tasks.
- Capture in Today schedules today; Upcoming schedules tomorrow; Next, Waiting and Someday use their respective status. Project/area capture assigns that collection. Capture from search or filters goes to Inbox. The destination shown when capture opens is retained if you navigate before submitting.
- If a save is delayed, text typed after submission remains in capture when that save finishes. Canceling and reopening capture also starts a new input session, even when the title is identical.
- Select a task and use **Task → Reschedule Selected Task…** for an exact date. Reschedule moves scheduled and deadline dates together, preserving their signed calendar-day separation. For a deadline-only task, it moves the deadline; an undated task gains a scheduled date. To edit just one date, use its inspector control.
- A row click selects the task while keeping list focus and the current inspector visibility. **Command-E** opens details and focuses the title for editing; the trailing toolbar button also toggles details. Double-click a task title to edit it inline. The inspector title uses a placeholder instead of a separate label, wraps across multiple lines and expands up to six visible lines; edits autosave.
- **View Options → Sort** offers title, priority, scheduled date, deadline, newest created/updated, and exact file path. Missing dates/priorities sort last; ties use exact paths.
- Choose **View Options → Sort → Custom** to drag tasks into your own order. Order is saved separately for each view in the vault config and travels between machines; switching to another sort and back retains it. New tasks appear after ordered tasks. Grouped views support reordering within each group, and temporarily hidden tasks retain their places. Custom sorting is an app display override, including for saved filters; it does not rewrite task Markdown or change CLI sorting. While Custom is active, row drags reorder the list; use the inspector to assign projects/areas, or switch to another sort to drag onto sidebar destinations.

## Markdown Titles And Notes

Task titles support inline Markdown: `**bold**`, `*italic*`, `` `code` ``, and `[label](https://example.com)` links. Rows and the inspector display the formatted title. Click the inspector title to edit its Markdown source, or use **Command-E**. Leaving the field returns it to rendered text. Rows retain their selection and reorder gestures.

Notes show rendered Markdown by default: paragraphs, headings, ordered/unordered lists, blockquotes, fenced code and inline formatting with clickable links. Click the notes (or **Add notes…**) to edit their source with normal autosave. Moving focus elsewhere, clicking outside the field or pressing Escape returns to rendered text without discarding edits. Keyboard users can focus either rendered field and press Return to edit. There is no separate preview mode or duplicate title preview.

Use explicit Markdown links or angle-bracket autolinks such as `<https://example.com>`. This is native text rendering, not an HTML renderer; images, tables and embedded HTML are not rendered as rich content. Checklist controls remain above Notes and change only the check marker.

Rendered fields use the current draft, including unsaved edits, and never rewrite Markdown. Titles remain strings in frontmatter and notes remain the file body; CLI output, copying, search and sorting continue to use the source text.

## Repeat And Checklists

Use the always-visible **Repeat** picker in the task inspector. Choose a fixed schedule (frequency, interval and optional weekly weekdays) or an interval after completion.

Project, area and **Tags** are also always visible. Use the **+** beside Tags to enter a tag or choose an existing one, and a token’s **×** to remove it. Each entry is one tag, including names containing commas.

Fixed completion follows the existing cadence until the next occurrence is after the completion day. After-completion recurrence starts its interval on that day in the vault timezone. Monthly/yearly recurrence retains calendar clamping; see [the file contract](FILE_FORMAT.md#recurrence).

Write checklist steps in Notes using Markdown checkboxes such as `- [ ] Draft outline`. Recognized steps appear as native checkboxes above Notes. Toggling a step changes only its marker. Code blocks and comments remain untouched; see [supported checklist syntax](FILE_FORMAT.md#body-checklists).

**Reset checklist on repeat** is per task and defaults off. When enabled, recurring completion unchecks recognized steps. Ordinary completion leaves notes unchanged.

## Projects

Choose a project in the sidebar to edit its title, status and notes in the inspector. If a task is selected, use **Edit Project** above the task list. Title edits do not rename or move files.

Complete/Reopen changes only the project, not its tasks. Someday, done and canceled projects appear under **Inactive Projects**, collapsed by default. An inactive project already assigned to a task remains visible in that task's inspector.

Routine project destinations in the command palette include active projects only; use the sidebar's Inactive Projects section for review or reopening.

Right-click a project or area to delete it. Remove task, project and saved-filter references first; deletion never cascades. Native Undo restores the exact Markdown during the current vault session.

## Combined And Saved Filters

Choose **New Filter** or press **Command-Shift-F**. Combine a view, project/area, statuses, required tags, priorities, text and scheduled/deadline ranges. All dimensions must match; statuses/priorities are alternatives, and every selected tag is required. Enable **Include completed and canceled tasks** when reviewing finished work.

Results update as criteria change. Name the query and choose **Save Filter**. Select a saved filter in the sidebar and use **Edit Filter → Update Filter** to change it. A different, unused name saves a copy. Choosing an automatic sort for a saved filter opens its working editor so the definition is updated intentionally. **Custom** uses the shared presentation order in the vault config and keeps the saved filter open without rewriting its query definition.

Working criteria are temporary until explicitly saved. Named definitions live in `.config/filters.md` and are shared with the CLI. If another client changes that file, local criteria remain available: **Use File Version** loads the saved definition; **Keep Working Filter** reloads other definitions and permits an explicit subsequent save. Malformed definitions and missing references are surfaced rather than repaired.

## Keyboard Reference

| Action | Shortcut |
| --- | --- |
| Capture / submit / cancel | Command-N / Return / Escape |
| New vault window | Command-Shift-N |
| Today / Inbox / Next | Command-1 / Command-2 / Command-3 |
| Upcoming / Waiting / Someday | Command-4 / Command-5 / Command-6 |
| Search / filter editor | Command-F / Command-Shift-F |
| Command palette | Command-K |
| Complete or reopen selection | Command-Return |
| Edit selected task | Command-E |
| Delete selected task (task list focused) | Backspace |
| Reschedule to an exact date | Command-D |
| Reschedule for today / tomorrow | Command-Shift-T / Command-Shift-D |
| Undo / redo | Command-Z / Command-Shift-Z |

The sidebar, lists, pickers, checkbox controls, text fields and date popovers use native keyboard-accessible controls. Hosted keyboard tests cover Backspace editing in the inspector and deletion from the focused list. Complete live focus traversal and VoiceOver behavior remain manual acceptance work.

## Saving And Conflicts

Task and project drafts autosave, survive navigation, and are flushed before quitting. Invalid input, missing files, write failures and overlapping external changes retain drafts for correction or recovery. Non-overlapping edits rebase onto the file. Completion, checklist reset and rescheduling group their related changes for undo/redo. External file changes invalidate stale history.

Project/area path moves are currently disabled in both clients; editing a title does not move its file. See the [roadmap](ROADMAP.md) for remaining iCloud, recovery and real-use validation.

## CLI Equivalents

```sh
taskmark list --view upcoming --sort deadline
taskmark list --view waiting --tag work --priority p1
taskmark reschedule Tasks/review.md --to 2026-09-20 --dry-run
taskmark filter save "Waiting work" --view waiting --tag work --sort priority
taskmark filter run "Waiting work"
taskmark filter delete "Waiting work" --dry-run
```

Run these inside the vault or supply `--vault PATH`. CLI mutations support `--dry-run`; the app and CLI share domain transitions and storage validation.

`edit --status done` also rolls recurring tasks forward, using all fields edited in that command. This intentionally changes the earlier status-only behavior. Remove recurrence in the same command (`--clear-recurrence --status done`) to finish permanently. `show --json` includes the recurrence mode, full `repeat_rule` or `repeat_after`, and checklist-reset preference.
