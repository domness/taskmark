# Repeated-Attempts Log

Read this file before suggesting an approach similar to a previous multi-attempt failure. Add an entry when an approach takes more than 2 attempts to work.

## 2026-09-21: Startup Split Layout Needs Flexible Content Boundaries

- What did not work: Sidebar width/default-window adjustments alone did not fix the vault-loading regression. A detail minimum of 320 points caused more native constraint-update failures; an outer GeometryReader also failed to resolve the cycle.
- What worked instead: Place the inspector on the detail content, with explicit flexible minimum-zero width wrappers for detail and inspector content, alongside native column/window sizing. The hosted regression passes across 840/1088/1120-point windows, inspector toggles and selection.
- Note for next time: Test the chooser-to-loaded-vault transition and content minima, not only windows created with an already-loaded model. Put Swift Testing UI regressions in a named suite to run them directly with Xcode's test filter; inspect xcresult summaries for quiet-run failures.

## 2026-09-21: Bound Resize Tests By Both Screen And Window Limits

- What did not work: The hosted macOS runner clamped the Settings test's requested 800-point content height to 684. Making the target screen-aware but subtracting a fixed 40 points for the smaller size then requested 624 points, below the runner's 628-point content minimum.
- What worked instead: Derive the larger size from the screen's visible content area and clamp the smaller size to the actual window minimum. Require at least ten points of resize range and check both growth and shrinkage with bounded layout polling. The revised test passes the local full quality gate.
- Note for next time: Native window tests must account for screen chrome and runtime content minima on the actual runner, rather than assuming development-display dimensions.

## 2026-09-21: Wait For Native Inspector Toolbar Propagation

- What did not work: Two full quality runs failed the existing inspector-toggle label assertion after a fixed 300 ms sleep, with stale labels in different presentation states.
- What worked instead: Poll for the single correctly labeled toolbar item with a bounded two-second timeout, then retain both original count and label assertions. The complete quality gate passed after this test synchronization change.
- Note for next time: Native presentation and toolbar updates are asynchronous; wait for the observable state rather than assuming a fixed animation duration. Do not remove duplicate-item or stale-label assertions.

## 2026-09-18: Bundled CLI Export And Case-Insensitive App Paths

- What did not work: Initial installer validation hit a formatter/linter disagreement around a compact catch and FileWrapper's string-keyed attributes. Embedding lowercase `taskmark` beside uppercase `Taskmark` overwrote the app executable on the default case-insensitive filesystem, causing the app test host to run the CLI.
- What worked instead: Use a multiline do/catch and string-keyed attributes including both file type and POSIX permissions (FileWrapper raises an Objective-C exception if the type is omitted); put the CLI in the standard nested-code directory `Contents/Helpers/`, and clean the old build products before revalidating.
- Note for next time: Never colocate product names distinguished only by case. FileWrapper attributes are string-keyed, unlike FileManager attributes. Verify the actual bundled executable and an exported standalone copy, not just SwiftPM output.

## 2026-09-18: Shared-Configuration Test And Settings Lifecycle Updates

- What did not work: A closure whose only throwing operations were inside Swift Testing macros was inferred as nonthrowing during several test-compilation passes. Adding a Settings save-status inset also caused SwiftUI to reapply a nonresizable window style after the one-time anchor callback.
- What worked instead: Evaluate throwing async setup in an ordinary `let` before asserting its result. The Settings anchor now rechecks the style after native window updates and changes it only when the resizable bit is missing. Shared-preference save/discard races use a paused-filesystem fixture rather than timing-only tests.
- Note for next time: Validate the real Settings scene after changing its content structure, and keep throwing setup visible to closure type inference outside assertion macros.

## 2026-09-18: Multi-Window AppKit Boundaries In Swift 6 Tests

- What did not work: Returning the non-Sendable NSWindowDelegate through `MainActor.assumeIsolated`, including via a captured variable, failed strict concurrency checking. Standalone hosted windows also had no environment UndoManager and did not reliably become OS key windows in the test runner, so global-menu activation was not a valid focus test there.
- What worked instead: A narrowly documented weak delegate reference is accessed only on the main actor, with runtime main-actor preconditions at Objective-C forwarding entry points. Each window delegate owns its UndoManager. Tests exercise the actual WindowGroup creation action, isolated native-window close/save behavior, and the delegate's Settings-context routing without pretending a background test host has OS focus.
- Note for next time: Distinguish scene-level integration from standalone hosting. Preserve SwiftUI delegate forwarding, validate per-window history ownership, and do not weaken Sendable checking for the entire AppKit import.

## 2026-09-18: Hosted Native Drag Tests

- What did not work: A pasteboard-writer check alone passed even while a row-wide Button intercepted mouse tracking. SwiftUI accessibility traversal did not expose that button reliably. Posting a sequence of mouse events through NSApp failed to complete a reorder, and removing the button could leave the synthetic test in native drag tracking until timeout.
- What worked instead: Keep deterministic native drag-source and selection wiring checks alongside model move/persistence tests; remove the row-wide control from the native reorder hit region. Reserve physical drag acceptance for a real UI automation/manual session.
- Note for next time: In-process keyboard event tests do not imply synthetic mouse events can complete a WindowServer drag session. Do not treat a hanging drag harness as a product failure or a passing model test as gesture proof.

## 2026-09-18: Notarization Profile Lookup Must Select A Keychain

- What did not work: Retrying implicit profile lookup reported a missing `local-todo-dominic` item; after the user restored it explicitly, implicit lookup returned HTTP 401 while the same profile in the login Keychain authenticated successfully. Treating changing GitHub runner IDs as evidence of machine replacement was misleading: the manager creates ephemeral registrations for each job.
- What worked instead: Pass the explicit persistent Keychain path to every notarytool call. Use the same wrapper for a read-only authentication preflight and actual submissions. Tests verify default/custom paths, argument preservation and failure propagation without real credentials.
- Note for next time: Compare explicit and implicit lookup before attributing failures to a revoked password or deleted credential. Never dump passwords or reset unrelated Keychains. The original disappearance remains unexplained; another project's latest nightly run skipped its Keychain steps.

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
