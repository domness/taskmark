# Run Your Day Acceptance Evidence

Run Your Day is implemented and its automated acceptance checks pass. This record distinguishes automated evidence from unverified live UI behavior.
All automated vault workflows use disposable temporary directories; new workspace tests also isolate preferences and use injected clocks/timezones where date behavior matters.

## Implemented

- Fixed completion skips missed occurrences through the completion day; after-completion stays anchored to that day. Signed paired-date offsets remain intact. Domain tests cover early/late completion, selected weekdays, multi-week intervals, month/year clamping, deadline-only and undated tasks; existing timezone/DST tests remain passing.
- Optional V1 `reset_checklist_on_repeat` defaults off. Recognized checklist markers alone are reset. Domain/codec tests cover Unicode, CRLF, code/comment exclusion, malformed values, backward-compatible defaults and round trips.
- CLI add/edit exposes the reset preference; completion uses the shared transition. `CLIRecurrenceTests` exercises both recurrence modes, real reloads, unknown frontmatter, dry runs, and disabling reset.
- Task inspector has native fixed/after-completion recurrence controls, weekday selection, interval/unit controls, and an opt-in reset checkbox. Edits use workspace-owned autosave and native history.
- Task notes expose interactive checklist toggles backed by the shared body projection. Stale projections are rejected. Raw notes remain available for writing steps and other Markdown.
- App completion flushes pending draft edits before calculating the shared transition. Regression tests first reproduced row completion ignoring an unsaved repeat rule; both row and inspector paths now persist the correct dates and checklist state.
- `WorkspaceRepeatEditingTests`, `WorkspaceChecklistEditingTests`, and `WorkspaceChecklistResetTests` exercise autosave after selection changes, reload, undo/redo, external recurrence/notes/reset conflicts, explicit conflict resolution, and pending-edit completion. Existing retry, unavailable-file, and date-conflict suites remain passing.
- Project title/notes/status editing now uses workspace-owned autosave. Complete/reopen uses shared domain transitions. Active projects appear in routine navigation; inactive projects remain accessible in a collapsed section. `WorkspaceProjectTests` and `WorkspaceProjectConflictTests` cover persistence, actual workspace reload, title/path/reference preservation, unknown frontmatter, status undo/redo, concurrent field rebases/conflicts, malformed-file recovery, in-flight typing, and injected write-failure retry. `CLIProjectTests` verifies the shared project lifecycle.
- Shared queries now support Upcoming/Waiting/Someday and stable sorting by path, title, priority, scheduled/deadline dates and newest creation/update. Domain/CLI tests cover inclusive combined filters, missing values, exact paths, date boundaries and invalid ranges/options.
- Named filters persist in canonical `.localtodo/filters.md`, shared with CLI `filter save/list/run/delete`. Storage tests cover all query fields, fresh-store reload, unknown top-level/entry fields and Markdown notes, stale create/update/delete revisions, injected write failure, malformed definitions, missing-reference diagnostics, symlink refusal and coordinator remaps.
- The app has combined-filter controls, saved-filter sidebar navigation, explicit Save/Update, sort choices, and conflict recovery. `WorkspaceFilterTests` and `WorkspaceFilterConflictTests` prove real task results, save/update and fresh-workspace reload, history, invalid/duplicate rejection, retention after write failure, missing/malformed definitions, and keeping a working filter without overwriting external definitions. Test workspaces now isolate display preferences as well as bookmarks and vault files.
- Upcoming/Waiting/Someday are now sidebar and keyboard destinations. Contextual capture, selected-task completion/reopening, exact-date and today/tomorrow rescheduling are exposed through native menus, shortcuts and the command palette. Shared app/CLI rescheduling preserves paired-date offsets and notes. `WorkspaceDailyWorkflowTests`, `WorkspaceDailyFailureTests`, `TaskRescheduleTests` and `CLIRescheduleTests` cover each daily route, injected-clock capture/reload/completion/history, rescheduling/history, stale sessions, external planning-input conflicts, write-failure retry, and capture failure. [Daily workflow documentation](DAILY_WORK.md) lists the controls and shortcuts.

## Final Acceptance Audit

| Requirement | Implementation and automated evidence |
| --- | --- |
| Inspect/edit both recurrence modes | Native repeat controls and `RecurrenceEditorValue`; `WorkspaceRepeatEditingTests` covers editing, removing, autosave, history, validation and conflicts. CLI status-edit parity and full JSON rule fields are covered by `CLIStatusRecurrenceTests`. |
| Fixed vs after-completion advancement | Shared `TaskTransition`; `FixedCompletionTests` and `TaskTransitionTests` cover late/early completion, selected weekdays, multi-week intervals, clamping, signed date offsets, undated/deadline-only tasks and DST. |
| Interactive checklist subtasks and opt-in reset | Shared byte-preserving projection and native toggles; domain, codec, workspace checklist and CLI recurrence tests cover default-off, CRLF/Unicode, code/comment exclusion, reload, history and conflicts. |
| Project title/notes, complete/reopen, inactive navigation | Project drafts/inspector and active/inactive sidebar sections; workspace project suites and `CLIProjectTests` cover file identity/references, autosave/reload, completion/history, rebases, true conflicts, unavailable files and write-failure retry. |
| Combined/saved filters and useful sorting | Shared query/sort and canonical filter metadata, native editor and sidebar; domain/CLI/filter-store/workspace filter suites cover all dimensions, results, reload/update/clear, history, missing values/references, malformed definitions, stale revisions and write failures. |
| Daily views and keyboard actions | Sidebar/routes, native menus, command palette and shortcuts; `WorkspaceDailyWorkflowTests` covers capture, reload, completion/history and rescheduling/history in all three routes. Native keyboard wiring compiles; physical focus/shortcut traversal is not manually verified. |
| Planning/date-offset consistency | Shared app/CLI rescheduling plus recurrence; `TaskRescheduleTests`, `CLIRescheduleTests`, workspace daily and acceptance tests cover offsets, unchanged notes, no-ops, incomplete-state validation, injected dates, and semantic conflicts during undo. |
| Storage/architecture preservation | Domain remains UI/YAML/filesystem-independent; Markdown owns serialization and writes; clients use shared APIs. Existing safety/move/recovery tests pass. New tests preserve nested recurrence metadata and saved-filter unknown fields/body, and prove explicit clearing survives disk reload. |
| Relevant failures and recovery | Injected task/project/filter write failures, failed capture and recurring completion, external edits, stale identities/revisions, malformed files, symlinks and coordinator remaps are covered. The tested failures retain drafts or fail without replacing external content. |

The audit first reproduced and then fixed unknown nested recurrence-key loss, cleared saved-filter criteria reappearing after reload, and CLI status edits bypassing recurring completion. `WorkspaceAcceptanceTests` additionally verifies recurring-completion failure/retry with a fresh app-model reload, planning conflicts during undo, filter clearing, and persisted/legacy sort preferences.

A follow-up acceptance pass reproduced a delayed capture write clearing newer input. `WorkspaceCaptureConcurrencyTests` now proves retention after newer typing, cancel/reopen with the same title, and a queued submission receipt. The command palette also uses the same tested active-project projection as routine sidebar navigation.

The intentional CLI change is documented: `edit --status done` rolls a recurring task forward from the edited inputs. Use `--clear-recurrence --status done` to finish permanently. The commit uses a breaking-change footer. The new optional reset field and filter metadata file require no migration of existing vault notes.

## Verification Boundary

Final `make check` passed: formatting, strict lint, **41 domain tests, 59 Markdown/storage tests, 15 CLI tests, and 66 macOS app tests**, followed by a successful app build. These are 181 test functions; parameterized cases are additional. Each cohesive implementation checkpoint was quality-gated, committed and pushed; final clean-tree/upstream synchronization is verified at handoff.
No live UI inspection or screenshots have been performed. Rendered layout, VoiceOver traversal and physical keyboard focus behavior are not yet verified; native controls and accessible labels are implemented and compile-tested.

Todoist migration, a real-use pilot, mobile/web clients, iCloud validation, and project/area file moves are excluded.
