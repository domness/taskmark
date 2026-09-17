# Repeated-Attempts Log

Read this file before suggesting an approach similar to a previous multi-attempt failure. Add an entry when an approach takes more than 2 attempts to work.

## 2026-09-17: Hosted SwiftUI Keyboard Event Tests

- What did not work: Direct `NSWindow.sendEvent` and `NSTableView.keyDown` calls did not traverse SwiftUI’s application-level key handling, even with native selection and first responder confirmed. Adding alternate SwiftUI key handlers did not fix the bypassed dispatch path.
- What worked instead: Post the synthetic key through `NSApp.postEvent` and await event processing to exercise normal keyboard dispatch. Handle Backspace explicitly with list-scoped `onKeyPress` for the delete control characters; `onDeleteCommand` alone did not delete. The regression also verifies that Backspace in the real inspector title field edits text instead.
- Note for next time: Verify native selection and first responder, then use the application event queue rather than calling lower-level key handlers directly.

## 2026-09-17: Universal Archive Architecture Verification

- What did not work: Xcode 27's `lipo -verify_arch arm64 x86_64` rejected the single quoted app-binary input with “requires exactly one input file,” whether the input preceded or followed the command.
- What worked instead: `xcrun lipo -archs` successfully reported `x86_64 arm64`; validate each complete architecture token in that output. The Release archive itself built successfully, with the expected marketing/build versions.
- Note for next time: Verify the architecture-inspection command against a real universal archive rather than assuming the documented flag form works with the selected toolchain.

## 2026-09-17: Native Settings Screenshot Evidence

- What did not work: NSHostingView bitmap capture omitted AppKit vibrancy/titlebar layers (black sidebar selection and missing header detail). Filtering a top-level Swift Testing function by its bare name selected zero tests. Target-level testing ran the capture, but full-window `screencapture` returned “could not create image from window” in this environment.
- What worked instead: Use target-level execution for the opt-in capture utility; retain passing behavior/build evidence and explicitly leave live native appearance verification outstanding. Do not accept the incomplete bitmap captures as a visual pass. The OS capture path requires a window-server session with capture permission.
- Note for next time: Verify that at least one Swift test actually runs and inspect the full native window capture before using it as evidence. Do not attempt to repair app visuals based on missing layers in an offscreen cache.

## 2026-09-17: Extending Near-Limit SwiftUI Views

- What did not work: Adding appearance controls exceeded TaskListView's type-body limit; extracting only the appearance menu still left it two lines over the enforced limit on the next lint run.
- What worked instead: Extract the appearance menu and move route-heading/selection projections into a focused extension, then rerun the formatter and strict lint.
- Note for next time: Check the existing type/function size before extending a view near the limit; extract a complete responsibility rather than shaving individual lines.

## 2026-09-16: Checklist Byte Projection Linting

- What did not work: Direct non-failable UTF-8 conversions triggered the optional-data-string rule; a file-wide exemption then triggered the blanket-disable rule.
- What worked instead: Centralize conversion of already-valid, ASCII-edited String bytes in one private function with a documented, single-line exemption.
- Note for next time: Prefer narrowly documented lint exceptions for proven byte invariants; never disable a rule for an entire file.

## 2026-09-16: Long Throwing Loop Predicates

- What did not work: A loop containing only an `if` triggered `for_where`; moving its long throwing condition into `where` then let SwiftFormat put the opening brace on a separate line, conflicting with SwiftLint.
- What worked instead: Extract the per-component validation into a named throwing function and call it from the loop.
- Note for next time: Keep long predicates out of loop headers when the formatter and linter disagree; prefer a named validation step to rule suppression.

## 2026-09-16: Removing Optional Yams Mapping Fields

- What did not work: Replacing a whole recurrence node lost unknown nested metadata. Updating a `Node` preserved metadata, but assigning nil through `Node` subscripting was a no-op, leaving obsolete recurrence keys and cleared saved-filter criteria on disk.
- What worked instead: Mutate `Node.Mapping`, whose nil assignment removes keys, then wrap it as `.mapping`. Regression tests cover recurrence mode changes and fresh-store reload after clearing all optional saved-filter criteria.
- Note for next time: Test both setting and clearing optional YAML fields after serialization. `Node` and `Node.Mapping` have different nil-setter behavior.

## 2026-07-27: Vault Initialization Failure Recovery

- What did not work: The first rollback removed `.localtodo` recursively after a failed manifest write. The next version made manifest creation exclusive but still used recursive removal for temporary-file cleanup and checked directory emptiness only before setup.
- What worked instead: Publish the manifest with `renameatx_np` and `RENAME_EXCL`, clean temporary files with POSIX `unlink`, remove rollback directories with POSIX `rmdir`, revalidate directory contents immediately before publication, and map a concurrent manifest to an actionable domain error.
- Note for next time: For filesystem transactions, review every cleanup path for recursive deletion and every check-then-write sequence for races. Add injected-failure and concurrent-change tests before considering the path complete.

## 2026-07-27: Autosave And History Race Hardening

- What did not work: Initial autosave and undo implementations treated refresh, selection, and mutation work as mostly independent. Repeated review found stale refresh publication, autosave/history races, and undo operations that could advance the native stack before acquiring their filesystem mutation path.
- What worked instead: Track vault sessions and model epochs, serialize mutations per path, merge successful writes immediately into the snapshot, keep drafts in the workspace model, and reserve history mutation paths before asynchronous filesystem work begins.
- Note for next time: Design asynchronous UI mutations as state machines before adding convenience behavior. Reserve shared resources synchronously, make stale-result rejection explicit, and add delayed-store race tests alongside happy-path tests.

## 2026-07-27: Drag Assignment And Draft Reconciliation

- What did not work: Routing sidebar assignments through autosave made failed writes retry without undo history. The first direct-write replacement then let an overlapping unrelated draft edit restore the old assignment, and it treated same-target drops as changes because patches always advance `updatedAt`.
- What worked instead: Persist assignments as direct field-specific transitions, reject same-target drops before applying a patch, reconcile only the assigned draft field when unrelated edits overlap, and register field-specific undo only after a successful write with an unchanged draft generation.
- Note for next time: For async commands that overlap editable drafts, define ownership for every field before writing. Detect no-ops from semantic fields before applying timestamped patches, and test failed writes plus overlapping local edits.

## 2026-09-08: Move Safety Requires More Than Exclusive Publication

- What did not work: The original move transaction used sequential writes and suppressed rollback failures. The first task-only replacement validated entity paths but not the manifest, and reserved-path checks initially missed case aliases on case-insensitive volumes.
- What worked instead: Disable collection moves pending recovery design, coordinate both exact task paths, use exclusive rename, validate the manifest before mutation, and reserve metadata-directory case variants. Report a successful rename followed by refresh failure explicitly rather than describing it as an uncommitted move.
- Note for next time: Test preflight configuration failures and filesystem aliases alongside write failures. Symlink integration tests also exposed that calling `skipDescendants()` on a symlink can skip real sibling entries; DirectoryEnumerator already avoids traversing links.

## 2026-09-08: Inspector Recurrence And Conflict Regression Tests

- What did not work: Plain status editing bypassed recurrence. Calculating dates before autosave fixed rollover and undo, but field-only conflict detection still merged external cancellation or repeat-rule changes with dates derived from the old task. One test also compared in-memory fractional timestamps with second-precision persisted timestamps.
- What worked instead: Use the shared transition once before autosave, group its draft edits for undo, and treat external recurrence/status changes as dependencies of recurring planning edits. Assert unchanged file bytes when testing conflict preservation rather than comparing a pre-serialization timestamp.
- Note for next time: Test semantic dependencies of calculated edits, not only overlapping keys. Include tasks already in Next, since recurring completion then changes dates without changing status.
