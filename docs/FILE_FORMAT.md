# File Format

Status: initial V1 contract. Any incompatible change requires a schema migration, tests, documentation, and a breaking-change commit.

## Vault

A vault is a user-selected directory containing `.localtodo/config.yml`:

```yaml
schema: 1
timezone: Europe/London
```

`timezone` is optional. When omitted, Today uses the current system timezone. The app may store disposable indexes under `.localtodo/cache/`; cache content is never canonical and must be safe to delete.

Creating a vault requires an empty directory. Opening an existing vault requires a valid manifest and never reinitializes the folder.

Typed Markdown files may live anywhere below the vault except `.localtodo/`. Folder names do not define workflow semantics.

## Identity And References

The exact, case-sensitive, vault-relative path is entity identity. There are no generated IDs.

```yaml
project: Projects/Local Todo.md
area: Areas/Personal Systems.md
```

- References use `/` separators and include `.md`.
- Absolute paths, `..`, and paths escaping the vault are invalid.
- App-driven moves update known references atomically.
- External moves can break references; clients report them and `localtodo doctor` will diagnose them.
- Changing only a file title does not change identity. Renaming or moving its path does.

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
- Projects, areas, tags, and priorities are queries over explicit metadata.
- Completion updates the existing file in place; automatic archiving is outside V1.

## Recurrence

V1 supports fixed calendar recurrence and intervals after completion.

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

After-completion intervals use exactly `P<n>D`, `P<n>W`, `P<n>M`, or `P<n>Y`, where `<n>` is from 1 through 999. Completing a recurring task keeps the same path and advances its scheduled date, deadline, or both according to the rule.

## Mutation Guarantees

- Validate a full mutation before writing any destination.
- Use atomic replacement and never leave a partially written entity.
- A path move and its reference updates succeed together or leave the vault unchanged.
- Dry runs report intended path and field changes without writing.
- JSON CLI output distinguishes validation, conflict, missing-reference, and I/O failures.
