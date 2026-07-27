# Project Memory

This file records significant project decisions and end-of-session summaries. Read it before making changes or recommendations. Canonical product, architecture, and file-format details remain in their dedicated documents; this log records decisions rather than duplicating those specifications.

## Decision Log

### 2026-07-27: Persist Session Decisions And Repeated-Attempt Lessons

- What was decided: Maintain `MEMORY.md` as the decision and session-summary log, and `ERRORS.md` as the log for approaches that take more than 2 attempts.
- Why: Future sessions need durable context about project choices and failed approaches without relying on conversation history.
- What was rejected and why: Relying only on chat summaries was rejected because they are not guaranteed to be available in later sessions. Duplicating all canonical documentation here was rejected because parallel specifications drift.

### 2026-07-27: Make New Vault Initialization Conservative And Recoverable

- What was decided: New vaults require an empty directory, revalidate contents during setup, publish the manifest with an atomic exclusive rename, and clean up only with non-recursive file and empty-directory operations.
- Why: Initialization must not overwrite a concurrently created manifest, delete user content, or leave failed setup artifacts that prevent a safe retry.
- What was rejected and why: Existence checks followed by replacing writes were rejected because they race. Recursive cleanup was rejected because concurrent content could be deleted.

### 2026-07-27: Keep Autosave State In The Workspace Model

- What was decided: Task drafts and their debounced autosave work are owned by `WorkspaceModel`, survive inspector and selection changes, and are flushed before application termination.
- Why: View-owned save work can be canceled by ordinary navigation and can lose edits while the canonical Markdown file still appears unchanged.
- What was rejected and why: Explicit Save and Discard controls were rejected for routine task editing because they make lightweight task management feel form-like. View-local autosave tasks were rejected because view lifetime is not document lifetime.

### 2026-07-27: Rebase Non-Overlapping Changes And Surface True Conflicts

- What was decided: External changes to fields untouched by the user are adopted automatically. Concurrent changes to the same field remain unresolved until the user chooses the file version or keeps local changes.
- Why: Local-first editing should preserve both external and in-app work without forcing conflict prompts when changes can be merged safely.
- What was rejected and why: Last-writer-wins was rejected because it silently loses data. Treating every revision change as a conflict was rejected because it interrupts safe, non-overlapping edits.

### 2026-07-27: Use Native Undo Around Persisted Mutations

- What was decided: App mutations register with the macOS `UndoManager`; task-transition history restores only fields changed by that transition, while creation history removes or recreates the entity.
- Why: Undo should use familiar platform behavior without overwriting unrelated edits made after the original action.
- What was rejected and why: Snapshot-wide restoration was rejected because it can roll back unrelated concurrent changes. A custom parallel history stack was rejected because it would diverge from native Edit menu behavior.

### 2026-07-27: Recover Unavailable Task Files Without Overwriting

- What was decided: A dirty draft whose file was deleted can recreate that exact task. If the path is occupied by malformed content or another entity, recovery saves the task at a new path and leaves the external file untouched.
- Why: Recovery must preserve in-app edits without replacing user-authored content or changing another entity's path identity.
- What was rejected and why: Retrying autosave forever was rejected because it traps the draft and blocks quitting. Replacing invalid or different-type content was rejected because Markdown files remain canonical and externally owned.

### 2026-07-27: Coordinate Exact Entity Paths And Reject Identity Remaps

- What was decided: Revision-checked updates and deletes coordinate the exact entity URL, use the coordinator-provided URL, and fail if coordination remaps it to a different vault-relative path.
- Why: The coordinator must protect the actual file operation, but following a move would silently change canonical path identity.
- What was rejected and why: Coordinating only the vault root was rejected because it does not serialize child-file replacement. Blindly following a remapped URL was rejected because paths, not hidden IDs, are entity identity.

### 2026-07-27: Use Compact Date Buttons With Progressive Date Entry

- What was decided: Scheduled and deadline dates use compact inspector buttons that open a popover with quick choices, exact `YYYY-MM-DD` entry, and a graphical calendar. Planning weeks start Monday and weekends start Saturday.
- Why: Routine date planning should take little inspector space while preserving fast keyboard entry, accessible selection state, and deterministic shortcuts.
- What was rejected and why: Persistent inline date text fields were rejected because they consumed scarce inspector width. Calendar-only entry was rejected because distant dates and pasted values would become unnecessarily slow.

## Session Summaries

Add summaries here when the user says "session end", "wrapping up", or "let's stop here".
