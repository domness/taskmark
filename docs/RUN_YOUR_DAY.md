# Run Your Day Acceptance Evidence

This is an implementation/evidence ledger, not a claim that the milestone is complete.
All automated vault workflows use disposable temporary directories.

## Implemented

- Fixed completion skips missed occurrences through the completion day; after-completion stays anchored to that day. Signed paired-date offsets remain intact. Domain tests cover early/late completion, selected weekdays, multi-week intervals, month/year clamping, deadline-only and undated tasks; existing timezone/DST tests remain passing.
- Optional V1 `reset_checklist_on_repeat` defaults off. Recognized checklist markers alone are reset. Domain/codec tests cover Unicode, CRLF, code/comment exclusion, malformed values, backward-compatible defaults and round trips.
- CLI add/edit exposes the reset preference; completion uses the shared transition. `CLIRecurrenceTests` exercises both recurrence modes, real reloads, unknown frontmatter, dry runs, and disabling reset.
- Task inspector has native fixed/after-completion recurrence controls, weekday selection, interval/unit controls, and an opt-in reset checkbox. Edits use workspace-owned autosave and native history.
- Task notes expose interactive checklist toggles backed by the shared body projection. Stale projections are rejected. Raw notes remain available for writing steps and other Markdown.
- App completion flushes pending draft edits before calculating the shared transition. Regression tests first reproduced row completion ignoring an unsaved repeat rule; both row and inspector paths now persist the correct dates and checklist state.
- `WorkspaceRepeatEditingTests`, `WorkspaceChecklistEditingTests`, and `WorkspaceChecklistResetTests` exercise autosave after selection changes, reload, undo/redo, external recurrence/notes/reset conflicts, explicit conflict resolution, and pending-edit completion. Existing retry, unavailable-file, and date-conflict suites remain passing.

## Remaining Acceptance Gaps

- Project title/notes editing, complete/reopen, and inactive-project navigation in the app, including autosave/history/conflict evidence.
- Combined and saved filters over project, status, tags, priority and dates, with useful sorting and reload evidence.
- Upcoming, Waiting, and Someday routes with keyboard-accessible capture, completion and rescheduling, and workflow tests.
- Broader injected write-failure evidence for new mutations and final cross-workflow acceptance review.
- Final documentation, passing quality gate, clean tree and remote synchronization after the remaining work.

## Verification Boundary

The latest implementation checkpoint passed `make check`: formatting, strict lint, 34 domain tests, 51 Markdown tests, 6 CLI tests, 41 macOS app tests, and app build (parameterized cases are additional to test-function counts).
No live UI inspection or screenshots have been performed. Rendered layout, VoiceOver traversal and physical keyboard focus behavior are not yet verified; native controls and accessible labels are implemented and compile-tested.

Todoist migration, a real-use pilot, mobile/web clients, iCloud validation, and project/area file moves are excluded.
