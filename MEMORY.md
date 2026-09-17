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

### 2026-07-27: Keep Task-List Controls And Display Preferences In The List Column

- What was decided: Search, capture, inspector, and display controls live in an adaptive middle-column header. Each route persists its own project, area, and tag visibility plus optional project or area grouping.
- Why: Window-level toolbar placement obscured column ownership, while different task views need different context without forcing one dense row design everywhere.
- What was rejected and why: A single global row layout was rejected because project, area, and tag views have different redundant metadata. A fixed-width header was rejected because the inspector and sidebar can leave a narrow list column.

### 2026-07-27: Organize Tasks Through Named Pickers And Vault-Bound Dragging

- What was decided: The inspector edits project and area references through named pickers, and task rows can be dragged onto project or area sidebar destinations using an own-process payload bound to the current vault session. Drop assignments persist as direct field-specific transitions, and their undo is registered only after persistence succeeds.
- Why: Users should not need to type canonical paths for routine organization, while drag-and-drop must not apply external, stale, or cross-vault references. Direct transitions keep failed assignments out of autosave retries and let undo restore only the assigned field.
- What was rejected and why: Raw or externally readable drag payloads were rejected because external or stale values could target the wrong vault. Temporarily changing the inspector draft and registering undo before the write were rejected because failures and overlapping edits could leave unreliable history.

### 2026-09-08: Target A Dedicated Personal Task Vault

- What was decided: Keep one Markdown note per task in a dedicated task vault. Subtasks are Markdown checkboxes inside the parent task's body. The user's essential Todoist replacement workflows are recurring tasks, subtasks, filters, and projects; sharing is not needed.
- Why: This matches the user's intended workflow and the existing file contract, allowing daily-driver work to focus on reliability and missing app interactions rather than a new storage model.
- What was rejected and why: Indexing tasks scattered across general-purpose notes and integrating into an existing Obsidian vault were rejected for this workflow because the user explicitly prefers individual task notes and a dedicated vault. First-class child-task entities are unnecessary for the requested checkbox-based subtasks. Sharing is outside the user's needs.

### 2026-09-08: Harden Metadata, Recurrence, And Mutation Paths

- What was decided: Reject collection-shaped values in optional scalar frontmatter fields, reserved entity paths, NUL, and symlink components below the vault root. After-completion recurrence anchors on the completion day, and paired dates preserve their calendar-day offset. Fixed recurrence retains one-step advancement and checklists remain unchanged.
- Why: Malformed user content must be diagnosed rather than erased, mutations must not follow static links outside their intended paths, and completing a late recurring task must not calculate its interval from an obsolete date.
- What was rejected and why: Treating malformed optional fields as absent was rejected because later edits discard them. Resetting checklists or skipping missed fixed occurrences was not introduced because those are separate workflow decisions. Static link checks are not represented as protection against malicious concurrent filesystem swaps.

### 2026-09-08: Disable Unsafe Collection Moves Pending Recovery Design

- What was decided: Temporarily reject all project/area path moves, including dry runs, before mutation. Task moves coordinate both exact paths and use exclusive atomic rename, preserving file bytes. Keep the all-or-nothing reference-update requirement for any future collection-move implementation.
- Why: Review exposed a conflict between the documented atomic move contract and the old sequential writes with suppressed rollback errors. Multi-file Markdown changes are not one atomic filesystem operation. Even an apparently unreferenced collection can acquire references from another writer, so scanning for references alone is not sufficient to enable a safe collection move.
- What was rejected and why: Continuing best-effort rollback was rejected because failure or interruption can leave mixed references. Adding a journal alone was rejected as a claim of atomicity because recovery does not hide intermediate states from external editors. A new transaction/recovery design is deferred rather than weakening the storage contract; users can edit collection titles without changing paths.

### 2026-09-08: Calculate Inspector Recurrence Before Autosave

- What was decided: Selecting Done for a recurring task calculates the shared completion transition from the current valid draft and vault timezone. Apply its status and dates together as one native undo group, then persist through existing autosave. Pending notes and other edits stay intact. External repeat-rule changes conflict with local recurring planning edits; external status changes conflict with local recurring date edits.
- Why: Inspector completion must match the completion action without advancing again on autosave retry or redo. Recurrence/status changes invalidate the assumptions behind calculated dates even when their YAML keys do not overlap. These are semantic conflicts, rather than safe non-overlapping edits under the earlier merge decision.
- What was rejected and why: Applying recurrence on every draft save was rejected because retries, overlapping edits, and history replay can repeat the transition. Status-only undo was rejected because it leaves the advanced dates behind. Silently adopting a concurrent cancellation or repeat-rule change while saving the calculated dates was rejected because it applies an invalidated completion.


### 2026-09-16: Skip Missed Fixed Occurrences For Run Your Day

- What was decided: At the user's explicit request, fixed completion walks the existing cadence until its next date is strictly after the vault-local completion day; early completion still advances once. After-completion intervals remain anchored to the completion day. Paired dates retain their signed calendar-day offset.
- Why: Completing late must produce usable future work rather than another overdue occurrence. This intentionally revises the one-step decision recorded on 2026-09-08. No persisted schema changes are needed for this transition change.
- What was rejected and why: Anchoring fixed recurrence to today was rejected because it changes the cadence. Changing monthly clamping while skipping was rejected because it is a separate recurrence-rule change.

### 2026-09-16: Record The macOS Personalization Wishlist

- What was decided: Capture the user's requested vault CSS stylesheets in `.config/`, task Duplicate/Delete/Copy context actions, independent project/area drag ordering, and P1 red/P2 orange/P3 blue/P4 default highlighting in `docs/ROADMAP.md`. Delivery order and unresolved behavior are explicitly proposals.
- Why: These improvements support daily use and personalization while making native UI and file-contract dependencies visible before implementation.
- What was rejected and why: Treating CSS as directly supported by SwiftUI or silently reserving `.config/` was rejected because each requires an explicit implementation/contract design. Reordering by moving collection files was rejected because sidebar order is presentation and collection path moves remain disabled for safety.

### 2026-09-16: Opt In To Checklist Reset Per Task

- What was decided: Add optional V1 task field `reset_checklist_on_repeat`, defaulting off. Shared completion resets recognized checklist markers only when the task repeats and the option is true. Use a conservative shared body projection for checklist controls and reset, preserving every other byte.
- Why: The user explicitly requested a per-task reset option. This intentionally revises the blanket no-reset decision from 2026-09-08 while retaining its behavior for existing notes. A missing field remains false, so migration is unnecessary.
- What was rejected and why: Global reset was rejected because repeat workflows differ. First-class subtask entities and Markdown re-rendering were rejected because they would change the one-note model and unrelated content. Ambiguous Markdown constructs remain text rather than risking changes to code examples.

### 2026-09-16: Edit Repeats And Checklist Markers Through Task Drafts

- What was decided: Keep recurrence and checklist-reset settings in workspace-owned task drafts, with native inspector controls and the same autosave, conflict and history paths as other fields. Checklist toggles change draft notes through the shared byte-preserving projection and reject a stale projection. Row completion saves pending draft edits before calculating recurrence.
- Why: Completion must use the rule and notes currently being edited, including a newly added repeat rule. A regression test reproduced the old row action completing the stale on-disk non-recurring task and conflicting with the pending rule.
- What was rejected and why: View-owned persistence was rejected because selection changes must not lose edits. Separate checklist files and a rendered-Markdown rewrite were rejected because the parent body remains canonical. Calculating from the old record then merging pending repeat settings was rejected because its dates and reset behavior would be wrong.

### 2026-09-16: Manage Projects Through Persistent Drafts And Active Navigation

- What was decided: Project title, notes and status use workspace-owned debounced drafts, field-specific undo, revision-checked writes, non-overlapping rebases and explicit conflict resolution. Routine sidebar and assignment choices show active projects; a collapsed Inactive Projects section retains someday, done and canceled projects for review/reopening. An already-assigned inactive project remains selectable in the task inspector.
- Why: Project management should be possible without YAML or path moves, and finishing a project should remove it from routine navigation without hiding its content permanently. Project completion changes only the project file, not its tasks.
- What was rejected and why: Cascading task completion and collection moves were rejected because they change unrelated task state or violate the current collection-move restriction. View-owned saves were rejected because navigation and application termination must retain/flush edits. Missing/malformed project files block saving and retain local notes until restored or explicitly discarded.

### 2026-09-16: Define Daily Query Membership And Stable Sorting

- What was decided: Upcoming includes incomplete tasks with either date strictly after the injected local day; Today retains its existing overdue/on-day semantics, so mixed-date tasks may appear in both. Waiting and Someday follow explicit status. Combined filters intersect dimensions, use OR within statuses/priorities, require every tag, and use inclusive valid date ranges. Shared sort modes break ties by exact path and put missing dates/priorities last.
- Why: App and CLI need one predictable query contract, including boundary dates and tasks with only deadlines. Existing Today behavior must remain intact.
- What was rejected and why: Mutually exclusive Today/Upcoming membership was rejected because it would hide a future deadline solely due to an overdue planned date. Client-specific sorting/filtering was rejected because results would diverge. Reversed ranges are rejected rather than silently returning misleading empty results.

### 2026-09-16: Keep Saved Filters In Canonical Vault Markdown

- What was decided: Store named queries in optional `.localtodo/filters.md` with a versioned frontmatter list and shared Domain/Markdown APIs. Preserve unknown top-level/entry keys and body notes; use exact-file coordination, exclusive creation, atomic replacement and whole-file optimistic revisions. Diagnose malformed definitions and missing project/area references. Expose the same definitions through CLI save/list/run/delete.
- Why: Saved filters are user-authored data, not a disposable index. Keeping them in the vault makes reloads and CLI/app use consistent without hidden identifiers or a canonical database. The optional metadata file needs no migration of existing task notes.
- What was rejected and why: UserDefaults-only storage was rejected because it would strand definitions outside the vault and CLI. Encoding Swift enum representations directly was rejected because the file format should remain legible. Automatic conflict overwrite/repair was rejected because another client's definitions and unknown metadata must survive.

### 2026-09-16: Separate Working Queries From Saved Filter Definitions

- What was decided: The app previews working criteria immediately and saves named definitions only through explicit Save/Update. Changing a saved filter's sort opens its working editor. Ordinary per-view sorting stays a display preference. Named definition writes use their edit-start revision; conflicts retain working criteria and require Use File Version or an explicit Keep Working Filter rebase before another save. Save operations use native undo/redo and block vault switching while in flight.
- Why: Exploring task queries is ephemeral; changing a reusable vault definition should be intentional. Background refresh must not silently authorize an overwrite of another client's saved filters.
- What was rejected and why: Autosaving every filter toggle into a named definition was rejected because exploratory changes would rewrite shared preferences unexpectedly. Making saved filters a cache or silently replacing duplicate names was rejected because they are user-authored vault data. Task/project document autosave remains unchanged.

### 2026-09-16: Add Contextual Daily Capture And Paired-Date Rescheduling

- What was decided: Add Upcoming/Waiting/Someday navigation and native task keyboard commands. Capture remembers its opening route: Today/Upcoming schedule today/tomorrow, Next/Waiting/Someday use their explicit status, and project/area capture assigns that collection. Search/filter capture remains Inbox. A shared reschedule transition shifts the existing planning anchor and paired dates by calendar days; independent inspector date edits retain their previous behavior.
- Why: Daily routes need immediately usable capture, completion and planning without YAML. Shifting both dates preserves the user's planning separation, including negative offsets and DST. Workspace tests inject a clock and explicit timezone.
- What was rejected and why: Reading the route only at submission was rejected because navigation could silently change the destination. Recalculating recurrence during rescheduling was rejected because planning is not completion. Merging external planning-input changes with an already-calculated transition was rejected; related drafts and undo/redo retain semantic conflict dependencies.

### 2026-09-16: Close Recurrence And Filter Persistence Gaps In Acceptance Review

- What was decided: Preserve unknown nested recurrence keys during edits/mode changes, and remove cleared optional filter criteria at the YAML mapping level. Make CLI `edit --status done` invoke recurring completion from the edited inputs, matching the inspector, and expose full recurrence expressions in additive JSON fields. Permanent completion is explicit removal of recurrence plus Done.
- Why: Regression tests reproduced nested-key loss, filter criteria reappearing after reload, and CLI status edits bypassing recurrence. The CLI status-edit change is intentional and breaking; it is documented and committed with a breaking-change footer.
- What was rejected and why: Keeping divergent app/CLI completion was rejected because users should not get different next dates from the same action. Replacing whole recurrence mappings was rejected because unknown metadata belongs to users. Assigning nil through Yams `Node` was rejected because it silently does nothing; mutation uses `Node.Mapping` instead.

### 2026-09-16: Preserve New Capture Input Across Delayed Saves

- What was decided: Bind capture completion to a UI-input generation captured at submission. A completed write clears/dismisses only the capture it submitted, preserving later typing and canceled/reopened captures even when the title is identical. The command palette uses the same active-project projection as routine sidebar navigation.
- Why: A paused-filesystem regression reproduced successful task creation erasing newer capture input. Inactive projects also remained visible in the routine palette despite being collapsed in the sidebar.
- What was rejected and why: Comparing text alone was rejected because a newly opened capture may intentionally use the same title. Disabling all typing during filesystem coordination was rejected because preserving input supports fast capture without unnecessary waiting. Inactive projects remain explicitly accessible through the sidebar's review section.

### 2026-09-17: Require Explicit Xcode App Build Evidence

- What was decided: Clarify that the full `make check` gate must pass before handoff or commits, and require a regenerated, normal signed clean Debug build when investigating Xcode Build/Run failures. Add a repository PR template recording toolchain, commands/results and separate launch/UI evidence.
- Why: Swift package checks do not compile the macOS app, and the existing unsigned build gate does not exercise normal Xcode signing. The reported failure was not reproduced on this checkout with Xcode 27.0 (27A266a): the signed clean build and full quality gate passed.
- What was rejected and why: Claiming a source fix without a reproduced failure was rejected because it would misrepresent the evidence. Checking in the generated Xcode project was unnecessary; `project.yml` remains the project configuration source and `make generate` refreshes local source membership.

### 2026-09-17: Deliver Native Personalization And Row Interaction Fixes

- What was decided: Implement the four pending personalization requests with priority-colored indicators/labels, single-task context and Task-menu actions, per-vault device-local sidebar ordering, and an optional native CSS-token adapter at `.config/style.css`. Keep neutral titles and native focus behavior. Search consumes the available list height with a top-pinned header, sidebar navigation and its footer have separate layout space, and a full-width task-content button handles editing.
- Why: These choices address the reported interaction bugs and the recorded wishlist while retaining the native interface and Markdown ownership model. Duplicate preserves unknown frontmatter/notes/recurrence, gets fresh timestamps and reopens completed copies. Delete uses exact-byte native Undo/Redo after persistence. Ordering is presentation only and does not require collection moves.
- What was rejected and why: System Trash was not chosen for this iteration; reversible deletion has explicit session-local recovery semantics. Implicit clipboard formats and batch actions were rejected in favor of three named copy actions on one task. Browser-style arbitrary CSS and reserving all of `.config/` were rejected because native tokens suffice and existing entity paths must remain valid. Full stylesheet syntax and manual visual acceptance checks are documented in `docs/PERSONALIZATION.md` and the roadmap.

### 2026-09-17: Use Native List Moves For Sidebar Reordering

- What was decided: Replace the custom collection drag payload and row drop handler with `ForEach.onMove` for Projects and Areas. Validate the captured source order, index bounds and vault session before saving the independent section order. Keep task-assignment drops on the collection rows.
- Why: The user reported that collection rows could be dragged but not reordered. The custom drag exported a payload without enabling native List insertion handling; its before-target algorithm also could not move a row after the last item. This revises the earlier custom collection-drag approach while preserving the device-local ordering decision.
- What was rejected and why: Retaining custom row dragging alongside native moves was rejected because it competes with the list's reorder gesture. Before-only insertion was rejected because downward and end-of-section moves must work naturally. Reordering by moving Markdown files remains prohibited.

### 2026-09-17: Consolidate Project Headers

- What was decided: Show the project draft title, status and Edit Project action once in the task-list header beside the list controls. Compact layouts use an edit icon and can wrap controls below the single project heading.
- Why: The filename-based route header duplicated the project title and consumed an extra row. The project name is the useful navigation label; the exact path remains available in the inspector's File section.
- What was rejected and why: Keeping a second filename heading was rejected as redundant. Removing the project status or edit action entirely was rejected because they remain useful project controls.

### 2026-09-17: Move Inspector Toggle To The Window's Trailing Toolbar

- What was decided: At the user's request, move the inspector toggle out of the middle-pane header and into the trailing window toolbar. When open, its toolbar item belongs to the inspector; when closed, it belongs to the main toolbar, keeping the action available at the window's right edge.
- Why: The control changes window layout and should occupy the top-right corner. This intentionally revises the inspector-control placement from the 2026-07-27 list-column decision; search, capture and display controls remain list-local.
- What was rejected and why: Keeping a duplicate middle-pane toggle or placing the only toggle inside a hidden inspector was rejected because it adds clutter or makes reopening inaccessible.

### 2026-09-17: Add Native Settings With Canonical Vault Time Zones

- What was decided: Add General/Theme sections in a native macOS Settings scene. Week start, date/time display formats, initial view, appearance, palette and stylesheet enablement are persistent device-local preferences. The user explicitly confirmed that time-zone edits update the active vault's canonical manifest through shared revision-checked storage. Unknown manifest values survive; dirty drafts and in-flight mutations block timezone changes.
- Why: App and CLI must continue to share Today/recurrence semantics, while display and startup preferences belong to this Mac. Week-start preferences affect graphical calendars and “Next week” suggestions only; shared recurrence retains its prior calculation calendar. This intentionally revises the fixed-Monday planning choice from 2026-07-27. Native deletion undo survives timezone updates because no task content changed.
- What was rejected and why: An app-only timezone was rejected by the user because it would diverge from CLI queries. Reformatting stored dates or changing recurrence week boundaries with a UI preference was rejected because it would alter the file/business contract. Clearing all undo history on timezone changes was removed after review because it discarded session-local deletion recovery.

### 2026-09-17: Separate Appearance Mode, Palette And Custom Overrides

- What was decided: System/Light/Dark appearance is independent of Local Todo, Slate, Forest and Sand palettes. Each palette has light/dark surface and accent tokens. Valid `.config/style.css` overrides merge over the selected palette; unsupported styles fall back to that palette with diagnostics. Add background/sidebar/inspector tokens while retaining native text, focus, selection and control semantics. Both workspace and Settings scene roots receive the same preferences.
- Why: Explicit dark mode and three additional themes were requested, with documented customization. Paired surfaces keep native text legible across appearance changes. Stylesheet enablement now persists across launches and vault switches, intentionally replacing the earlier session-only toggle behavior.
- What was rejected and why: Treating dark mode as a separate palette was rejected because every theme should support both modes. Arbitrary browser CSS and a custom text/control renderer remain rejected; native semantic states and bounded tokens keep the implementation understandable. `docs/SETTINGS.md` and `docs/THEMES.md` document behavior and extension points; full-window visual acceptance is not claimed because captures were unavailable.

## Session Summaries

Add summaries here when the user says "session end", "wrapping up", or "let's stop here".
