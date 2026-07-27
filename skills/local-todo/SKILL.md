---
name: local-todo
description: Manage a Local Todo Markdown vault through the localtodo CLI. Use when an agent needs to inspect, create, update, complete, search, organize, or validate Local Todo tasks, projects, areas, tags, priorities, scheduled dates, deadlines, and recurrence without editing frontmatter directly.
---

# Local Todo

Use `localtodo` as the only mutation interface. Markdown is user-owned, path identity is significant, and direct YAML edits can break references or discard unknown fields.

## Establish Context

1. Run `localtodo --version` and `localtodo --help`.
2. Locate the vault from an explicit user path, the current directory, or documented CLI configuration. Never search unrelated home-directory content for a vault.
3. Run `localtodo schema --json` before relying on field or status values.
4. Prefer `--json` for reads and parse the documented response rather than terminal formatting.

The scaffold currently supports schema introspection only. If a requested mutation command is absent from `--help`, report that limitation and do not fall back to direct frontmatter editing.

## Read Operations

When available, use CLI list, show, search, and doctor commands with `--json`. Pass filters explicitly and preserve returned vault-relative paths exactly, including case.

Do not infer that a missing task is deleted. Distinguish no matches, an invalid vault, malformed files, broken references, and I/O failures from exit codes and JSON error kinds.

## Mutation Operations

When mutation commands become available:

1. Resolve a target by its exact vault-relative path. Ask when multiple matches remain.
2. Run the command with `--dry-run --json`.
3. Inspect all field, path, and reference changes.
4. Execute without `--dry-run` only when the requested intent and preview agree.
5. Read the changed entity back and report the resulting path and status.

Never auto-confirm destructive or bulk changes. Never move a project or area with filesystem tools; the CLI must update references atomically.

## Domain Rules

- Task statuses are `inbox`, `next`, `waiting`, `someday`, `done`, and `canceled`.
- Priorities are `p1` through `p4`, with P1 highest; omitted priority means none.
- `scheduled` controls planned visibility; `deadline` is the hard cutoff.
- Today includes incomplete tasks scheduled or due on or before the vault's current date.
- Projects and areas are Markdown entities referenced by exact vault-relative path.
- Checklists live in task bodies and do not have independent task metadata.
- Completing a task updates it in place.

## Safety

- Never modify `.localtodo/cache/` as if it were canonical data.
- Never edit YAML directly when a CLI operation exists.
- Never invent UUIDs; identity is the path.
- Never normalize unknown frontmatter on the agent's own initiative.
- Never claim synchronization succeeded; report only local CLI results and surfaced conflicts.
- Use `localtodo doctor` before and after bulk operations when that command is available.
