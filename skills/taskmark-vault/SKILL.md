---
name: taskmark-vault
description: Read and manage Taskmark TODO vaults directly through Markdown, YAML frontmatter, and .config files when the taskmark CLI is unavailable or file-level work is requested. Use for finding, creating, editing, organizing, completing, and validating tasks, projects, areas, and saved filters without requiring the app or CLI.
---

# Taskmark Vault Files

Work with the user's selected Taskmark vault using filesystem tools and a safe YAML parser. This skill is portable: its bundled references contain the supported schema 2 contract; no Taskmark checkout, app, or CLI is required. If the CLI is available, prefer its shared validation and coordinated mutations for routine operations.

## Establish The Vault

1. Use the supplied vault directory, or locate `.config/config.yml` in the current directory or its nearest ancestor. Do not search unrelated home-directory content. If no manifest is found, ask for the vault location; do not initialize an existing folder to make it recognizable.
2. Read [the file schema](references/file-schema.md) and the actual manifest. Require `schema: 2` and valid present configuration fields. Earlier `.localtodo` layouts have no migration or fallback; do not silently convert them or guess a newer schema.
3. Recursively inspect Markdown files below that root, excluding reserved `.config/` and its case variants and without following symlinks. Recognize entities by frontmatter `type`, not directory or filename. Keep a list of malformed files and unresolved references alongside valid results; an incomplete scan is not evidence that references are absent.
4. Resolve requested entities to exact, case-sensitive vault-relative paths. Duplicate titles are allowed; disambiguate before editing. Dates such as “today” use the manifest timezone, or the current system timezone when omitted. Report the timezone used for date-sensitive work.

Folders such as `Tasks/`, `Projects/`, and `Areas/` are conventions, not required structure or workflow state. A task in `Inbox/` can have `status: next`. A checkbox in a task body is a lightweight step, not another task entity. A project's area does not implicitly assign that area to its tasks.

## Read And Query

Read the leading YAML frontmatter mapping separately from the remaining Markdown body. Do not parse YAML with line-based search/replacement or treat a later `---` in notes as frontmatter. Use a parser that does not execute arbitrary YAML tags; reject ambiguous duplicate keys rather than choosing a value silently. Quote strings when producing YAML, especially titles containing `: `, `#`, quotes, or line breaks.

- Incomplete means status is neither `done` nor `canceled`. By default exclude both, even in All Tasks.
- Inbox, Next, Waiting, and Someday match their explicit statuses.
- Today matches incomplete tasks with either `scheduled` or `deadline` on/before the vault-local day. Upcoming matches either date strictly after it. These views can overlap.
- Project, area, tag, and priority filters use explicit fields. Intersect filter dimensions; use OR within selected statuses/priorities and require every selected tag (case-sensitive).
- Scheduled/deadline ranges are inclusive, exclude missing dates, and reject start dates after end dates. Text search matches title, body, and tags case- and diacritic-insensitively.
- Default to exact-path order. Other shared sorts are title, priority (P1 first), scheduled/deadline (earliest first), and created/updated (newest first), with exact path breaking ties and missing dates/priorities last. Shared Custom order is a presentation overlay in configuration, not a filter criterion.

Report exact paths with results. Distinguish no matches from unreadable files, invalid YAML, unsupported schemas, and missing references. Resolve a `project` reference to an actual `type: project` file and an `area` reference to an actual `type: area` file; filenames alone are insufficient.

## Write Without Losing User Content

Direct editing does not automatically provide Taskmark's file coordination or conflict guarantees. Before mutation, establish a quiet editing window with app drafts flushed and other writers/sync activity paused, or use a filesystem mechanism that actually coordinates with them. A reread followed by rename is not compare-and-swap. If concurrent writes cannot be excluded or coordinated, provide a proposed patch instead of claiming a safe write.

For each requested mutation:

1. Read and retain the original bytes and exact path; validate the complete entity/configuration and all new references before writing. Reject absolute paths, `..`, NUL, reserved metadata entity paths, and symlink components below the root, including dangling links. Do not normalize case or invent IDs.
2. Patch only intended known fields in the parsed YAML mapping, preserving unknown keys and nested values. Preserve the Markdown body byte-for-byte unless the requested edit changes notes or checklist markers. Do not serialize the body through a Markdown renderer. Frontmatter formatting may normalize; avoid gratuitous formatting changes.
3. Keep `created_at`; set `updated_at` to the current UTC ISO 8601 timestamp for entity edits. Maintain `completed_at` according to the lifecycle below. Removing an optional field means deleting its mapping key (or a supported null), not writing an empty collection/string in its place.
4. Validate the entire proposed document, compare current bytes with the originals immediately before publishing, and stop on a changed revision. Re-read and recompute a conflicting operation; do not blindly retry old output. Status, recurrence, dates, and checklist-reset inputs are dependencies of completion, even when different YAML keys changed.
5. For replacement, write a sibling temporary file, flush it, and atomically replace the exact destination. For creation, use exclusive publication that fails if the destination exists, including case aliases on the filesystem. Do not truncate a live file or use check-then-overwrite creation. If available tools cannot do this, return the proposed content/patch for application with suitable tools.
6. Read back, parse, check references, and compare preserved content. Report actual paths and changes, diagnostics, and any unperformed operations. Local success does not establish synchronization success.

Do not repair malformed files, remove dangling references, or overwrite unknown metadata merely to make a requested edit succeed. Surface the specific problem; repair only when that is the user's requested work.

## Common Operations

- **Create:** Use a requested or convention-consistent unused `.md` path outside `.config/`, a non-empty title, `type: task`, `status: inbox` unless specified, and fresh equal UTC creation/update timestamps. Optional metadata can be omitted. Use the schema reference's minimal template, replacing its sample values. Do not overwrite a same-title task.
- **Organize:** Set `project`/`area` to validated exact paths, and tags to an ordered unique list of strings without a leading `#`. Preserve tag names containing commas. Rename the display `title` without renaming the file.
- **Complete a non-recurring task:** Reject a canceled task until explicitly reopened. Set `status: done`, retain an existing completion timestamp or set it to now, and update `updated_at`. Leave dates and notes intact; do not move it to an archive folder.
- **Complete a recurring task:** Read [recurrence and checklist transitions](references/recurrence.md) first. Advance the same task's dates, set `status: next`, and clear `completed_at`; simply writing `done` does not perform a repeat. Permanently finishing it requires the user's intent to remove recurrence and mark it done.
- **Reopen/cancel:** Reopen a done/canceled task to the requested incomplete status (Inbox by default); clear `completed_at`. Canceling sets `status: canceled` and clears `completed_at`. Neither operation calculates recurrence or changes dates/checklists.
- **Plan:** Editing one date changes only that field. Rescheduling moves the scheduled date (or deadline if no scheduled date exists) to the target day and shifts both existing dates by the same signed calendar-day delta. Undated tasks gain `scheduled`. Only reschedule incomplete tasks; do not advance recurrence or reset checklists.
- **Check a step:** Replace only the checkbox marker byte in a recognized body item; see the recurrence reference for recognition boundaries. Update the parent's `updated_at`. Checking all steps does not automatically complete the task.
- **Manage collections:** Projects use `active`, `someday`, `done`, `canceled`; areas use `active`, `archived`. Completing a project sets its own completion timestamp; reopening to active clears it. Do not cascade status or area changes to tasks.
- **Duplicate:** Publish a new sibling path exclusively; preserve body, unknown fields, recurrence, and planning metadata; refresh both timestamps. Done/canceled copies reopen in Inbox and clear completion time.
- **Delete:** Only delete requested entities after checking the retained revision. Project/area deletion requires a complete scan of task, project, and saved-filter references and must refuse remaining references; never cascade. Filesystem deletion has no app session Undo guarantee.
- **Move:** Project/area path moves remain disabled because sequential reference rewrites cannot satisfy all-or-nothing behavior; edit titles instead. A requested task move requires a same-filesystem exclusive atomic rename that preserves bytes and rejects occupied paths; do not fall back to copy/delete. Manual ordering does not require any move. Report remembered presentation paths that become stale rather than silently rewriting unrelated configuration.

## Configuration And Saved Filters

Read the relevant sections of [the file schema](references/file-schema.md) before changing `.config/config.yml` or `.config/filters.md`. These are canonical user data, not generated output. Preserve unknown root/nested keys and filter-document notes. Whole-file revisions matter; do not overwrite another writer's saved views or preferences. `.config/cache/` is disposable and never a source of tasks. `.config/style.css` is optional appearance configuration; it does not affect task semantics and is not arbitrary browser CSS.

For a bulk request, resolve targets and intended field changes before writing and report per-file outcomes. Multiple atomic replacements are not one atomic vault transaction; stop on a failure/conflict rather than claiming all-or-nothing success.
