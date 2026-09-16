# Repeated-Attempts Log

Read this file before suggesting an approach similar to a previous multi-attempt failure. Add an entry when an approach takes more than 2 attempts to work.

## 2026-09-16: Checklist Byte Projection Linting

- What did not work: Direct non-failable UTF-8 conversions triggered the optional-data-string rule; a file-wide exemption then triggered the blanket-disable rule.
- What worked instead: Centralize conversion of already-valid, ASCII-edited String bytes in one private function with a documented, single-line exemption.
- Note for next time: Prefer narrowly documented lint exceptions for proven byte invariants; never disable a rule for an entire file.

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
