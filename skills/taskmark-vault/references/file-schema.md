# Schema 2 File Reference

This reference is bundled so the skill works without a Taskmark source checkout. It follows the repository's authoritative `docs/FILE_FORMAT.md`; maintain it alongside contract changes.

## Layout And Manifest

```text
My Vault/
  .config/
    config.yml       required plain YAML manifest, not Markdown frontmatter
    filters.md       optional saved queries, with frontmatter and body
    style.css        optional native appearance tokens
    cache/           optional disposable derived data
  Tasks/Review.md    illustrative folders; typed Markdown can live elsewhere
  Projects/Launch.md
  Areas/Work.md
```

Minimal manifest: `schema: 2`. Optional `timezone` is a valid timezone identifier such as `Europe/London`; omission follows the current machine. Remove the key to select system timezone. Never infer the timezone from `date_format`. Creating a new vault, if requested, requires an empty directory; opening one never reinitializes it.

```yaml
schema: 2
timezone: Europe/London
preferences:
  appearance: system
  theme: standard
  week_start: 2
  date_format: iso
  time_format: twentyFourHour
  initial_view: today
  vault_stylesheet: true
```

`preferences` is optional; absent/null mapping or missing fields use defaults. Present fields must be valid:

| Key | Values; default |
| --- | --- |
| `appearance` | `system`, `light`, `dark`; `system` |
| `theme` | `standard`, `slate`, `forest`, `sand`; `standard` (Taskmark palette) |
| `week_start` | integer 1–7, Sunday–Saturday; 2 |
| `date_format` | `system`, `iso`, `dayFirst`, `monthFirst`; `system` |
| `time_format` | `system`, `twelveHour`, `twentyFourHour`; `system` |
| `initial_view` | `today`, `inbox`, `next`, `upcoming`, `waiting`, `someday`, `all`, `search`; `today` |
| `vault_stylesheet` | boolean; `true` |
| `sidebar_order` | optional mapping: `project`/`area` to ordered unique exact paths |
| `custom_order` | optional mapping: view key to `{isEnabled: boolean, paths: [ordered unique exact paths]}` |
| `views` | optional mapping: view key to display options below |

View keys: built-in view names, `search`, `filters`, `filter:<name>`, `project:<exact-path>`, `area:<exact-path>`, `tag:<tag>`, `priority:<p1|p2|p3|p4|none>`. Display options are boolean `showsProject`, `showsArea`, `showsTags`, `grouping` (`none`, `project`, `area`), and optional/null `sort` (`path`, `title`, `priority`, `scheduled`, `deadline`, `created`, `updated`).

```yaml
preferences:
  sidebar_order:
    project: [Projects/Launch.md]
  custom_order:
    inbox:
      isEnabled: true
      paths: [Tasks/Review.md]
  views:
    inbox:
      showsProject: true
      showsArea: true
      showsTags: false
      grouping: none
      sort: priority
```

These are fragments to merge, not replacements for the entire manifest. Ordering never moves files. Missing remembered paths are ignored; new tasks follow remembered tasks. Custom order is applied after query evaluation. Calendar display preferences do not change persisted ISO dates or recurrence rules. Copying a vault's preferences requires including the hidden `.config/` directory; Taskmark itself provides no sync transport.

## Entity Frontmatter

Entities are UTF-8 Markdown with a leading `---`-delimited YAML mapping and an arbitrary Markdown body. Minimal task example (replace sample title/path/timestamps for actual creation):

```markdown
---
type: task
title: "Review launch"
status: inbox
created_at: 2026-09-21T09:00:00Z
updated_at: 2026-09-21T09:00:00Z
---

Notes and links belong here.

- [ ] Check the release notes
```

| Task field | Contract |
| --- | --- |
| `type` | required `task` |
| `title` | required non-empty string; inline Markdown is source text |
| `status` | required `inbox`, `next`, `waiting`, `someday`, `done`, `canceled` |
| `created_at`, `updated_at` | required ISO 8601 UTC timestamps |
| `completed_at` | optional/null UTC timestamp for `done`; otherwise clear |
| `priority` | optional/null `p1`, `p2`, `p3`, `p4`; P1 highest, none differs from P4 |
| `scheduled`, `deadline` | optional/null valid calendar dates `YYYY-MM-DD`, without time |
| `project`, `area` | optional/null exact vault-relative paths to the corresponding entity type |
| `tags` | optional ordered unique strings without leading `#`; use a YAML list |
| `recurrence` | optional structured mapping; see `recurrence.md` |
| `reset_checklist_on_repeat` | optional boolean; absent/null/false defaults off; lowercase string `"true"`/`"false"` also accepted |

Do not coerce a list/mapping in a scalar field into absence. Use valid Gregorian dates and UTC timestamps rather than local display formats. References include `.md` and use `/`; exact case matters. Do not use absolute paths, `..`, or `.config/` (including case variants). Path identity has no hidden UUID and is independent of `title`.

Projects and areas share required `type`, non-empty `title`, `status`, `created_at`, and `updated_at`, plus optional tags and body notes:

```markdown
---
type: project
title: Launch
status: active
area: Areas/Work.md
tags: [release]
created_at: 2026-09-21T09:00:00Z
updated_at: 2026-09-21T09:00:00Z
completed_at: null
---

Project notes.
```

Project statuses: `active`, `someday`, `done`, `canceled`. Optional `area` references an area. `completed_at` is for Done; other statuses clear it. Completion never updates child tasks.

```markdown
---
type: area
title: Work
status: active
tags: []
created_at: 2026-09-21T09:00:00Z
updated_at: 2026-09-21T09:00:00Z
---

Area notes.
```

Area statuses: `active`, `archived`. Do not add task lifecycle fields to manage an area. Unknown keys on all entity types remain user-owned and must survive edits.

## Saved Filters

`.config/filters.md` has its own **schema 1**, independent of vault schema 2. A missing file means no saved filters; an existing file requires a `filters` list (possibly empty).

```markdown
---
schema: 1
filters:
  - name: Waiting work
    view: waiting
    project: Projects/Launch.md
    statuses: [waiting]
    priorities: [p1, p2]
    includes_no_priority: false
    tags: [work]
    scheduled_from: 2026-09-01
    scheduled_through: 2026-09-30
    include_completed: false
    sort: deadline
---

Optional notes about saved views.
```

- `name`: required, non-empty, unique and case-sensitive, without surrounding whitespace/newlines. Names identify entries, not entities.
- `view`: `all` (default), `today`, `inbox`, `next`, `upcoming`, `waiting`, `someday`.
- Optional criteria: `text`, `project`, `area`, `statuses`, `priorities`, `includes_no_priority`, `tags`, `scheduled_from`, `scheduled_through`, `deadline_from`, `deadline_through`, `include_completed`, `sort`.
- Missing collections default empty, booleans false, text empty, sort `path`. `priorities` contains P1–P4 enum strings; use `includes_no_priority` for unprioritized tasks, not a `none` entry. An empty priority list without that flag is unrestricted.
- Dates are fixed inclusive bounds; Today/Upcoming dynamically use the vault-local day. `include_completed` does not override Today/Upcoming's incomplete-only membership.
- Reject unknown enum values, invalid types/dates, reversed ranges, duplicate names, and invalid references. Retain unknown root/entry fields and the full body when editing existing definitions.
- Replacing one definition preserves other definitions; removing one does not remove tasks. Clearing criteria must actually remove keys. Do not rewrite `sort` when changing a Custom-order presentation preference.

## Optional Stylesheet

`.config/style.css` is user-authored UTF-8, at most 64 KiB, with bounded native tokens rather than a browser stylesheet. Missing/invalid styles fall back to built-in appearance and should be reported without rewriting. For task-management requests preserve it untouched; consult Taskmark's dedicated personalization/token documentation if styling is requested. `.config/cache/` remains disposable, unlike this stylesheet, manifest, and filter definitions.
