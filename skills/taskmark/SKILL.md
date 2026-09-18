---
name: taskmark
description: Manage a Taskmark Markdown vault through the taskmark CLI. Use when an agent needs to inspect, create, update, complete, search, organize, move, or validate Taskmark tasks, projects, areas, tags, priorities, dates, deadlines, and recurrence without editing frontmatter directly.
---

# Taskmark

Use `taskmark` for mutations. Markdown is user-owned, exact path identity is significant, and direct YAML edits can break references or discard unknown fields.

Taskmark was previously named Local Todo. The command is now `taskmark`, without a `localtodo` alias. Install it from **Taskmark → Install Command-Line Tool…**, choosing a writable folder on the shell's PATH. Reinstall after app updates to refresh the exported command. Vault schema 2 uses `.config/` for metadata and shared preferences; there is no migration or fallback for the earlier development layout.

## Establish Context

1. Run `taskmark --version` and `taskmark --help`.
2. Use an explicit user-provided vault with `--vault PATH`, or run inside a vault so the CLI resolves the nearest ancestor containing `.config/config.yml`. Never search unrelated home-directory content.
3. Run `taskmark schema --json` before relying on field or status values.
4. Run `taskmark doctor --vault PATH --json` before broad changes. Exit status 10 means diagnostics were found.
5. Preserve every returned vault-relative path exactly, including case.

## Read

Prefer JSON for reads:

```bash
taskmark list --vault PATH --json
taskmark show --vault PATH --json "Tasks/Exact Name.md"
taskmark search --vault PATH --json "launch"
taskmark doctor --vault PATH --json
```

Combine `list` and `search` filters as needed: `--view all|inbox|next|today|upcoming|waiting|someday`, repeated `--status`, `--project`, `--area`, repeated `--tag`, repeated `--priority` including `none`, `--scheduled-on`, `--scheduled-from`, `--scheduled-through`, `--deadline-on`, `--deadline-from`, and `--deadline-through`. Add `--all` only when completed and canceled tasks should be included. `--view all` selects the broad scope but does not itself include completed tasks. Use `--sort path|title|priority|scheduled|deadline|created|updated`; the app's shared Custom order is stored in the vault config and has no CLI sort equivalent.

Saved filters use `filter list`, `filter run NAME`, `filter save NAME [query options]` and `filter delete NAME`. Definitions live in `.config/filters.md`; `filter save --replace` explicitly updates an existing name. Deleting a filter does not delete its tasks.

Do not treat an empty result as deletion. Distinguish no matches from invalid vaults, malformed files, unresolved references, conflicts, and I/O failures. Vault command JSON responses use `api_version: 1` and `ok`; failures include `error.kind` and `error.message` and return a nonzero status. `schema --json` returns the schema summary directly.

## Mutate

For each mutation:

1. Resolve targets to exact paths. Ask when ambiguity remains.
2. Run the requested command with `--dry-run --json`.
3. Verify the resulting entity or source and destination paths.
4. Repeat without `--dry-run` only when the preview matches the request.
5. Read the changed entity back with `show --json` and report its exact path and status.

Examples:

```bash
taskmark add --vault PATH --dry-run --json "Tasks/Review.md" --title "Review" --status next
taskmark edit --vault PATH --dry-run --json "Tasks/Review.md" --priority p1 --scheduled 2026-08-01
taskmark complete --vault PATH --dry-run --json "Tasks/Review.md"
taskmark reschedule --vault PATH --dry-run --json "Tasks/Review.md" --to 2026-08-03
taskmark move --vault PATH --dry-run --json "Tasks/Review.md" "Tasks/Review launch.md"
```

Use repeated `--tag` to replace tags. Use explicit `--clear-priority`, `--clear-scheduled`, `--clear-deadline`, `--clear-project`, `--clear-area`, `--clear-tags`, or `--clear-recurrence` when clearing values. Project/area moves are disabled, including dry runs; change their display titles without renaming files. Only task moves are enabled, using an exclusive atomic rename. Never bypass the collection-move restriction with filesystem tools.

Never auto-confirm destructive or broad changes. Run `doctor` again after a sequence of related mutations.

## Domain Rules

- Task statuses are `inbox`, `next`, `waiting`, `someday`, `done`, and `canceled`.
- Priorities are `p1` through `p4`, with P1 highest; omitted priority means none.
- `scheduled` controls planned visibility; `deadline` is the hard cutoff.
- Today includes incomplete tasks scheduled or due on or before the vault's current date.
- Upcoming includes incomplete tasks with either date after the vault-local day; mixed-date tasks may appear in both Today and Upcoming. Waiting/Someday follow explicit status.
- Rescheduling shifts both dates by calendar days to preserve their signed offset. Editing an individual date remains independent.
- Projects and areas are Markdown entities referenced by exact vault-relative path.
- Checklists live in task bodies and do not have independent task metadata.
- Fixed recurrence uses `--repeat-rule`, for example `FREQ=WEEKLY;BYDAY=MO,WE,FR`.
- After-completion recurrence uses `--repeat-after` with `P1D`, `P2W`, `P3M`, or `P1Y` forms.
- Completing a recurring task rolls its dates forward in the same file rather than marking it done.
- Fixed completion skips missed occurrences while retaining cadence; after-completion intervals anchor on completion day. `edit --status done` applies recurrence to the edited inputs too. To finish permanently, remove recurrence with `--clear-recurrence --status done`.
- Checklists reset only when `reset_checklist_on_repeat` is enabled: use the `add --reset-checklist-on-repeat` flag or `edit --reset-checklist-on-repeat true|false`. Only recognized checkbox markers change; other body bytes remain intact.

## Safety

- Never modify `.config/cache/` as canonical data. `.config/` is reserved; never create task/project/area entities inside it.
- Never edit frontmatter directly when a CLI operation exists.
- Never invent UUIDs; identity is the path.
- Never normalize unknown frontmatter on the agent's own initiative.
- Never claim synchronization succeeded; report only local CLI results and surfaced conflicts.
- Never silently repair malformed files or unresolved references.
