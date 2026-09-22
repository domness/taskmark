# Project Memory

This file summarizes current, durable decisions that are not better expressed in the canonical product, design, architecture, file-format, or roadmap documents. Update an existing section when a decision changes; use Git history for chronology.

## Product And Scope

- Taskmark is a macOS-first, local-first task manager and CLI for a dedicated Markdown vault.
- The app combines fast capture and daily planning with transparent, user-owned files. It does not require an account, canonical database, or Taskmark sync service.
- Tasks are individual Markdown files. Lightweight subtasks remain Markdown checkboxes in the parent task body. Collaboration, first-class child-task entities, reminders, natural-language capture, and Todoist migration are outside current scope.
- iOS is the next planned client after desktop and storage reliability are established; web is later and must honor the same file contract.

## Naming And Compatibility

- The product, app bundle, CLI command, and companion skills are named Taskmark / `taskmark`.
- There is no `localtodo` CLI alias. Existing internal `LocalTodo*` Swift modules, generated Xcode project name, bundle identifier, and some build artifact names remain stable intentionally.
- Vault schema 2 is the only supported layout. All metadata and shared preferences live under reserved `.config/`; the earlier development layout has no migration or fallback.

## Storage And Identity

- Markdown files are canonical. Entity identity is the exact, case-sensitive, vault-relative path; there are no hidden UUIDs.
- Known-field mutations preserve Markdown bodies and unknown frontmatter. Malformed files, unresolved references, stale revisions, and unavailable files are surfaced rather than silently repaired or discarded.
- Task moves use coordinated exclusive atomic rename and preserve bytes. Project and area path moves remain disabled until multi-file reference updates have an honest recovery and external-visibility design.
- Project and area deletion is non-cascading and blocked by known references. Successful app deletion uses session-local exact-byte Undo/Redo and never overwrites an occupied restoration path.
- Direct-file agent work must acknowledge that ordinary filesystem tools do not reproduce Taskmark's file coordination or concurrency guarantees.

## Editing, Conflicts, And History

- `WorkspaceModel` owns task/project drafts, debounced autosave, conflict state, and persistence work so edits survive selection and inspector changes and flush before close or quit.
- Non-overlapping external changes rebase automatically. Concurrent edits to the same field, or to semantic dependencies of calculated transitions, require explicit file/local resolution.
- Native Undo registers only after successful persistence and restores the fields owned by an action rather than replacing unrelated state.
- Each vault window owns an independent workspace and UndoManager. Commands route through the focused window; shared settings operate on the most recently active workspace.

## Task Semantics

- Today includes incomplete tasks scheduled or due on/before the vault-local day. Upcoming includes incomplete tasks with either planning date after that day, so mixed-date tasks may appear in both.
- Combined filters intersect dimensions, use alternatives within status/priority selections, require every selected tag, and use inclusive date ranges. Stable sorts break ties by exact path and place missing dates/priorities last.
- Fixed recurrence retains cadence and skips missed occurrences until the next date is after completion day. After-completion recurrence anchors on completion day. Paired dates preserve their signed calendar-day offset.
- Checklist reset is opt-in per recurring task and changes only recognized checkbox marker bytes. Completion calculations use the latest valid draft and are applied once with grouped history.
- Saved filters are canonical user-authored `.config/filters.md`; working filter criteria remain temporary until explicitly saved.

## macOS Experience

- The focused canvas defaults to sidebar plus task list. Clicking a task row opens the inspector in reading mode without entering title editing; double-click edits the title inline and Command-E opens/focuses details.
- Task/project Markdown renders read-first and reveals source for editing. Source text remains canonical; no rich-text serialization or web view is used.
- Project, area, tags, and recurrence stay directly available in the inspector. Full-row task dragging supports sidebar organization and Custom list insertion without requiring prior selection.
- Sidebar order, Custom task order, view options, appearance, theme, stylesheet enablement, calendar/display settings, startup view, and timezone travel with `.config/config.yml`. Bookmarks and window geometry remain machine-local.
- Appearance and palette are independent. Taskmark, Slate, Forest, Sand, Catppuccin, and Dracula provide paired light/dark themes; a bounded `.config/style.css` token adapter may override native surfaces, accent, priority colors, base size, and row spacing.
- Native glass is limited to appropriate navigation/control surfaces on supported systems. Persistent task content stays opaque, with older-system and accessibility fallbacks.

## Distribution

- Taskmark supports macOS 15+ and ships as a universal Developer ID-signed, notarized app with a bundled signed CLI.
- Settings can register `/usr/local/bin/taskmark` through native administrator authorization. Registration is machine-local, refuses unrelated files, and does not edit shell profiles.
- Pull requests run the complete quality gate on hosted macOS. Main/manual quality and signed release packaging use the configured self-hosted macOS runner.
- GitHub Releases are the public download and changelog surface. Packaging success, Gatekeeper/signature checks, and manual downloaded-app interaction are distinct evidence.
