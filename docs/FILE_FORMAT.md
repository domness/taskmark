# File Format

Status: vault schema 2, introduced in Taskmark 0.1.0. The configuration layout is intentionally incompatible with the earlier development format. At the user's request there is no migration or `.localtodo` fallback. Future incompatible changes require an explicit compatibility plan, tests, documentation and a breaking-change commit.

## Vault

A vault is a user-selected directory containing `.config/config.yml`:

```yaml
schema: 2
timezone: Europe/London
preferences:
  appearance: dark
  theme: forest
  week_start: 2
  date_format: iso
  time_format: twentyFourHour
  initial_view: today
  vault_stylesheet: true
```

`timezone` is optional. When omitted, Today uses the current system timezone. The app may store disposable indexes under `.config/cache/`; cache content is never canonical and must be safe to delete.

Settings and display/order choices are canonical vault preferences in this file. Writes use exact-file coordination, whole-file optimistic revisions and atomic replacement. Unknown root and nested preference keys survive known-field edits; formatting/comments may normalize. Selecting System time zone removes the timezone key. Invalid schemas, malformed preferences, symlink components and stale revisions fail without rewriting the file. Calendar display choices do not change stored ISO dates, CLI formatting or recurrence calculation rules.

Creating a vault requires an empty directory. Opening an existing vault requires a valid manifest and never reinitializes the folder.

Typed Markdown files may live anywhere below the vault except `.config/`. Folder names do not define workflow semantics.

### Shared Preferences

`preferences` is an optional mapping; an absent/null mapping or missing known fields use the defaults below. Present field values must be valid, rather than being silently reset. Copy or synchronize the **entire vault, including `.config/`**, to carry the same choices between machines. Taskmark reads external changes during its regular refresh; it does not provide a synchronization transport.

| Key | Values / default |
| --- | --- |
| `appearance` | `system` (default), `light`, `dark` |
| `theme` | `standard` (Taskmark, default), `slate`, `forest`, `sand` |
| `week_start` | Integer 1–7, Sunday–Saturday; default 2 (Monday) |
| `date_format` | `system` (default), `iso`, `dayFirst`, `monthFirst` |
| `time_format` | `system` (default), `twelveHour`, `twentyFourHour` |
| `initial_view` | `today` (default), `inbox`, `next`, `upcoming`, `waiting`, `someday`, `all`, `search` |
| `vault_stylesheet` | Boolean, default `true` |
| `sidebar_order` | Optional mapping of `project` / `area` to ordered unique vault-relative paths |
| `custom_order` | Optional mapping of view keys to `{isEnabled: boolean, paths: [ordered unique paths]}` |
| `views` | Optional mapping of view keys to row display and automatic sort/grouping options |

`system` is a shared choice to follow the current machine's appearance, locale or timezone; select explicit values when identical presentation is wanted across machines.

View keys are built-in view names, `search`, `filters`, `filter:<name>`, `project:<exact-path>`, `area:<exact-path>`, `tag:<tag>` or `priority:<p1|p2|p3|p4|none>`. Each `views` entry has boolean `showsProject`, `showsArea`, `showsTags`, a `grouping` of `none`, `project` or `area`, and optional/null `sort` (`path`, `title`, `priority`, `scheduled`, `deadline`, `created`, `updated`). For example:

```yaml
preferences:
  sidebar_order:
    project: [Projects/Work.md, Projects/Home.md]
  custom_order:
    inbox:
      isEnabled: true
      paths: [Tasks/Second.md, Tasks/First.md]
  views:
    inbox:
      showsProject: true
      showsArea: true
      showsTags: false
      grouping: none
      sort: priority
```

Ordering uses exact paths and never moves entity files. Missing paths are ignored; newly discovered tasks follow remembered tasks. Custom ordering is applied by the app after query evaluation, not a CLI sort mode or a rewrite of saved-filter definitions.

Preference edits autosave and are flushed before closing/switching vaults or quitting. Different top-level preference fields can rebase over external changes. Concurrent changes to the same field (including an order/view mapping) retain the local draft and require Use File Preferences or Keep My Preferences. Machine-local bookmarks and window geometry remain outside this shared contract.

## Identity And References

The exact, case-sensitive, vault-relative path is entity identity. There are no generated IDs.

```yaml
project: Projects/Local Todo.md
area: Areas/Personal Systems.md
```

- References use `/` separators and include `.md`.
- Absolute paths, `..`, and paths escaping the vault are invalid.
- App-driven moves update known references atomically.
- Current safety restriction: only task moves are enabled. Project and area moves are rejected before mutation until multi-file reference updates have a safe recovery design. Editing a collection title does not require a path move.
- External moves can break references; clients report them and `localtodo doctor` will diagnose them.
- Changing only a file title does not change identity. Renaming or moving its path does.
- `.config/` and its case variants are reserved and cannot contain entity paths, including on case-sensitive volumes so vaults remain portable. Entity identity otherwise remains exact and case-sensitive. Mutation paths cannot contain NUL or symbolic-link components below the vault root, including dangling links. This check is not a sandbox against malicious concurrent filesystem changes.

## Task

Each task is one Markdown file. Frontmatter stores queryable fields and the body stores notes and lightweight checklist steps.

```markdown
---
type: task
title: Review local-first schema
status: next
priority: p2
scheduled: 2026-07-27
deadline: 2026-07-31
project: Projects/Local Todo.md
area: Areas/Personal Systems.md
tags:
  - design
  - local-first
created_at: 2026-07-27T09:15:00Z
updated_at: 2026-07-27T10:20:00Z
completed_at: null
---

Confirm that external editors can add unknown frontmatter safely.

- [ ] Test an external rename
- [ ] Test an iCloud conflict copy
```

### Known Task Fields

| Field | Required | Meaning |
| --- | --- | --- |
| `type` | yes | Always `task`. |
| `title` | yes | Non-empty display title. |
| `status` | yes | `inbox`, `next`, `waiting`, `someday`, `done`, or `canceled`. |
| `priority` | no | `p1`, `p2`, `p3`, `p4`, or `null`; P1 is highest. |
| `scheduled` | no | Planned calendar date in `YYYY-MM-DD`. |
| `deadline` | no | Hard cutoff calendar date in `YYYY-MM-DD`. |
| `project` | no | Vault-relative path to a project file. |
| `area` | no | Vault-relative path to an area file. |
| `tags` | no | Ordered, unique strings without a leading `#`. |
| `recurrence` | no | Structured recurrence definition described below. |
| `reset_checklist_on_repeat` | no | `true` to uncheck recognized body checklists on repeat; absent, `null`, or `false` defaults off. Lowercase string forms `"true"` and `"false"` are also accepted. |
| `created_at` | yes | ISO 8601 timestamp stored in UTC. |
| `updated_at` | yes | ISO 8601 timestamp stored in UTC. |
| `completed_at` | no | ISO 8601 UTC timestamp for `done`, otherwise `null`. |

Unknown keys must survive app and CLI changes to known fields. Known fields may be normalized into the documented representation. Frontmatter comments, key order, quoting, and whitespace are not guaranteed to survive.

## Projects And Areas

Projects and areas are first-class Markdown files with optional body notes.

```yaml
---
type: project
title: Local Todo
status: active
area: Areas/Personal Systems.md
tags:
  - software
created_at: 2026-07-27T09:00:00Z
updated_at: 2026-07-27T09:00:00Z
completed_at: null
---
```

Project status is `active`, `someday`, `done`, or `canceled`.

Completing a project sets its own status and `completed_at`; reopening sets `active` and clears `completed_at`. Neither action changes child task files or references. Title/notes edits keep the exact project path. Routine app navigation shows active projects; inactive projects remain available in a separate collapsed section.

```yaml
---
type: area
title: Personal Systems
status: active
tags: []
created_at: 2026-07-27T09:00:00Z
updated_at: 2026-07-27T09:00:00Z
---
```

Area status is `active` or `archived`.

## Derived Views

- Inbox contains incomplete tasks with `status: inbox`.
- Next contains incomplete tasks with `status: next`.
- Today contains incomplete tasks scheduled on or before today or with a deadline on or before today.
- Upcoming contains incomplete tasks with a scheduled date or deadline strictly after today. A task may appear in both Today and Upcoming when one date is overdue and the other is in the future.
- Waiting and Someday contain tasks in their corresponding explicit statuses, whether dated or undated.
- Projects, areas, tags, and priorities are queries over explicit metadata.
- Combined filters intersect project, area, status, priority, required tags, and inclusive scheduled/deadline ranges. Multiple statuses/priorities are alternatives; all selected tags are required and case-sensitive. A date range excludes undated tasks and its start must not exceed its end. Completed/canceled tasks require the include-completed option.
- Sorting supports exact path, title, priority (P1 first), scheduled/deadline (earliest first, missing last), and creation/update time (newest first). Ties use exact path. CLI defaults to path order.
- Completion updates the existing file in place; automatic archiving is not implemented.
- Rescheduling an incomplete task moves its scheduled date (or deadline when scheduled is absent) to a chosen date, preserving the signed calendar-day offset of paired dates. Undated tasks gain a scheduled date. Rescheduling does not complete/repeat the task or change checklist markers. Explicit edits to an individual date remain independent.

## Recurrence

Taskmark supports fixed calendar recurrence and intervals after completion.

Fixed form:

```yaml
recurrence:
  mode: fixed
  rule: FREQ=WEEKLY;BYDAY=MO,WE,FR
```

After-completion form:

```yaml
recurrence:
  mode: after-completion
  interval: P3D
```

Fixed rules use a strict RFC 5545 subset:

- `FREQ` is required and is `DAILY`, `WEEKLY`, `MONTHLY`, or `YEARLY`.
- `INTERVAL` is optional, defaults to 1, and is an integer from 1 through 999.
- `BYDAY` is optional and valid only with `WEEKLY`; values are unique `MO`, `TU`, `WE`, `TH`, `FR`, `SA`, or `SU` entries.
- No other rule fields are accepted.

Unknown sibling keys within the `recurrence` mapping survive known-field edits and mode changes. Switching modes removes only the other mode's known `rule`/`interval` key. Explicitly removing recurrence removes the whole definition.

After-completion intervals use exactly `P<n>D`, `P<n>W`, `P<n>M`, or `P<n>Y`, where `<n>` is from 1 through 999. Completing a recurring task keeps the same path and advances its scheduled date, deadline, or both according to the rule.

- After-completion rules calculate the next date from the injected completion day in the vault timezone, not the previous task date.
- Fixed rules advance from the previous scheduled date, or deadline when no scheduled date exists, repeatedly following the rule until the next occurrence is strictly after the completion day. Early completion still advances at least one occurrence. Monthly/yearly advancement retains the existing calendar clamping behavior (for example January 31 → February 28 → March 28).
- When both dates exist, the scheduled date anchors the recurrence and the deadline keeps its calendar-day offset from it, including across daylight-saving changes.
- A recurring task with neither date gets a scheduled date calculated from the completion day.
- Recurrence leaves the body unchanged unless `reset_checklist_on_repeat: true` is set. Then recognized checked markers become unchecked; all other body bytes are preserved. An absent preference defaults off. Ordinary non-recurring completion never resets checklists.

### Body Checklists

Interactive checklist items use `-`, `*`, `+`, or a 1–9 digit ordered marker ending in `.` or `)`, followed by whitespace and `[ ]`, `[x]`, or `[X]`. The closing bracket must be followed by whitespace or the end of the line. Up to three leading spaces are supported (including lightweight nested lists). Four-space indented code, blockquotes, escaped markers, HTML comments, and fenced code blocks are not interactive. More complex Markdown remains editable as notes. Toggle and reset operations replace only the one-byte check marker, preserving Unicode, line endings, spacing, and unrelated Markdown.

## Saved Filters

Optional `.config/filters.md` is canonical vault metadata, not a cache or task entity. It retains its own filter-document schema 1, independent of vault schema 2, and stores named query definitions in Markdown frontmatter:

```markdown
---
schema: 1
filters:
  - name: Waiting work
    view: waiting
    project: Projects/Local Todo.md
    statuses: [waiting]
    priorities: [p1, p2]
    includes_no_priority: false
    tags: [work]
    scheduled_from: 2026-09-01
    scheduled_through: 2026-09-30
    include_completed: false
    sort: deadline
---
Optional notes about these views.
```

- The file uses its own `schema: 1`; missing file means no saved filters. The `filters` list is required when the file exists, and may be empty.
- Names are non-empty, unique and case-sensitive, without leading/trailing whitespace or newlines. They identify entries within this metadata document, not task/project/area entities. Task identity remains its exact path; no hidden IDs are introduced.
- `view` is `all` (default), `today`, `inbox`, `next`, `upcoming`, `waiting`, or `someday`. Today/Upcoming resolve against the current vault-local day when run.
- Optional `text`, `project`, `area`, `statuses`, `priorities`, `includes_no_priority`, `tags`, `scheduled_from`, `scheduled_through`, `deadline_from`, `deadline_through`, `include_completed`, and `sort` follow the shared query semantics above. Absent collections are empty, booleans false, text empty, and sort `path`. Date bounds are fixed inclusive calendar dates. Unknown enum values, malformed fields, reversed ranges and duplicate names are rejected.
- Unknown frontmatter keys, unknown fields on retained named entries, and the full Markdown body survive edits. Explicitly deleting an entry removes its fields. Frontmatter formatting/comments may normalize as with task notes.
- Writes coordinate the exact metadata file, reject symlink components and coordinator remaps, compare the whole-file revision, then exclusively create or atomically replace it. Stale revisions fail rather than merging or overwriting other clients' saved views. A malformed file is surfaced and never silently repaired. Missing project/area references are reported in vault diagnostics and by saved-filter execution.
- Both app and CLI use the shared definition and query implementation. CLI commands: `filter list`, `filter save NAME [query options] [--replace]`, `filter run NAME`, and `filter delete NAME`; mutation commands support `--dry-run`.

## Shared Presentation And Optional Appearance

The macOS app stores display preferences and manual ordering in `.config/config.yml` as described above. A saved filter's canonical `sort` remains one of the shared query sorts even when the app displays it in Custom order. See [personalization](PERSONALIZATION.md).

### Optional Native Appearance

The macOS app optionally reads `.config/style.css`, a UTF-8 file up to 64 KiB, alongside the manifest and saved filters. Symlink components below the vault root are rejected. Missing or invalid styles use built-in appearance; diagnostics never cause stylesheet rewrites. The documented selectors, tokens, precedence and reload behavior are in [PERSONALIZATION.md](PERSONALIZATION.md). Styles do not change task semantics or Markdown mutations.

## Mutation Guarantees

### Task Copies And Reversible Deletion

Task duplication uses exclusive publication at a new sibling path, preserves body and unknown metadata, and refreshes creation/update timestamps. Completed/canceled copies reopen in Inbox; other statuses, recurrence and planning metadata remain. App deletion uses revision-checked deletion plus an in-memory exact-byte undo payload. Restoration is exclusive and refuses occupied paths; recovery history is local to the open vault session. These operations do not change the entity schema.

Project and area context-menu deletion uses the same exact-byte Undo/Redo recovery. Deletion is refused while tasks, projects, or saved filters reference the collection; remove those references first. It never cascades into other files. As with the existing collection-reference scan, this does not promise a multi-file transaction against concurrent external writers.

### Shared Guarantees

- Validate a full mutation before writing any destination.
- Use atomic replacement and never leave a partially written entity.
- A path move and its reference updates succeed together or leave the vault unchanged.
- Enabled task moves use a coordinated, exclusive filesystem rename and preserve the entire file byte-for-byte. Cross-filesystem moves fail rather than falling back to copy/delete. Multi-file collection moves remain disabled as described above.
- Dry runs report intended path and field changes without writing.
- JSON CLI output distinguishes validation, conflict, missing-reference, and I/O failures.
