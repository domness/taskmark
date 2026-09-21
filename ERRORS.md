# Repeated-Attempts Log

Read this file before suggesting an approach similar to a previous multi-attempt failure. Add an entry when an approach takes more than 2 attempts to work.

## 2026-09-21: Do Not Simulate macOS Text Scaling With DynamicTypeSize

- What did not work: A hosted native typography regression tried to prove scalable text by injecting SwiftUI `dynamicTypeSize` values and requiring a larger AppKit `NSTextField` point size. Neither `@ScaledMetric` nor a custom font relative to a semantic style changed the bridged field under this macOS host. Exact custom title-size assertions also ignored SwiftUI's semantic relative scaling.
- What worked instead: Keep `@ScaledMetric` at the scene appearance boundary, apply that already-scaled size once to bundled proportional fonts, and preserve semantic-role proportions from native sizes. Test configured body sizes, family changes, semantic hierarchy and scaled monospaced exceptions through actual native fields. Treat platform accessibility text-size acceptance as a native/manual boundary rather than fabricating a macOS setting through the SwiftUI environment.
- Note for next time: `dynamicTypeSize` injection is not evidence for bridged macOS control scaling. Do not replace relative/scaled production fonts just to satisfy fixed hosted point-size assertions; assert hierarchy unless the contract specifies an exact semantic-role size.

## 2026-09-21: Observe Native Test Readiness Instead Of Sleeping

- What did not work: PR #7 passed locally on Xcode 27/macOS 27 but failed Markdown reopening, list Backspace and inline-font checks on Xcode 16.4/macOS 15 CI. Fixed 100–150 ms waits, checking only editor insertion, and flushing drafts after posting an event did not establish native focus or completion of the queued command. Diagnostic iterations also showed that `activate()` cannot make this background test process active, cached native field references can be replaced during SwiftUI transitions, and the list can have no native selection despite a selected model path.
- What worked instead: Wait with bounded predicates for current native responders, editor removal, selection and the deletion result; issue each action only once. Resolve native controls after transitions, select the list row explicitly for the keyboard scenario, finish the separate text edit before posting a fresh list key event, and wait for inline-editor readiness before changing theme fonts. Keep all focus/content/deletion/family assertions, using a 0.01-point tolerance for native floating-point font sizes. Diagnostic failures report activation, responder class, modal/sheet state and scenario details.
- Note for next time: Hosted tests must exercise the window-local responder chain without assuming OS key-window activation. Avoid caching sibling native fields across conditional SwiftUI edits. A passing local run on a newer OS/toolchain is not CI evidence; verify the hosted macOS 15 run before handoff. Retain the earlier workspace-resource cleanup; readiness waits do not replace fixture cleanup or cure unexpected modal dialogs.
- Follow-up: The first CI update fixed Backspace but still caught editor focus failures. A predicate passing once can precede queued focus teardown, so require three consecutive observations across event-loop turns. Host inline typography in the actual task List with explicit native selection, and check standalone semantic fonts separately. The native trace then showed the inline field was installed while the table retained focus in the background host; enter the field's native editing session explicitly for the font measurement, leaving autofocus/gesture verification to the existing inline-editing suite. Keep a bounded responder-call trace in test windows for actionable remote failures.
- Toolchain note: Xcode 16.4 rejected `let table = try #require(table(in: host))` as a circular reference even though Xcode 27 accepted it. Name lookup helpers `findTable` so macro expansion cannot shadow them with the local result binding.

## 2026-09-21: Validate Bundled Fonts In The Actual App Host

- What did not work: The initial font test fixture used a nonexistent empty display-options initializer. After correcting it, runtime checks found that an arbitrary `INFOPLIST_KEY_ATSApplicationFontsPath` build setting was omitted from the generated Info.plist, and an inline editor activated before window presentation disappeared during initial focus setup.
- What worked instead: Generate the font-registration entry explicitly through XcodeGen's `info.properties`, copy the Fonts directory intact, and request inline editing after presenting the hosted window. Tests verify actual Core Text font URLs inside the app bundle, bold/italic faces, and live native field family/size changes.
- Note for next time: A successful build does not prove font registration. Inspect the running app's Info.plist and resolved font file URLs; use the real display-options defaults and follow established hosted-window focus lifecycle.

## 2026-09-21: Count Indentation In Embedded Shell Diagnostics

- What did not work: The CLI-registration lint pass failed on long UI/shell strings. Splitting the shell case arm still left its diagnostic two characters over the line limit because indentation counts too.
- What worked instead: Shorten the shell diagnostic and split Swift UI copy into concatenated literals. The full formatting/lint gate then passed.
- Note for next time: SwiftFormat does not wrap multiline shell-string contents; account for leading indentation when checking the 120-character limit.

## 2026-09-21: Host Markdown Focus Tests Through A View Controller

- What did not work: The Markdown title editor reopened successfully in isolation but immediately lost focus in the full macOS suite when hosted as a bare NSHostingView. Longer waits, waiting for the prior editor to disappear, ending the competing native field session, and extracting product FocusState ownership did not resolve the full-suite failure.
- What worked instead: Use NSHostingController as the test window's contentViewController. Retain bounded removal/insertion waits and the focus-loss, reopening, outside-click and content assertions. Revert the ineffective product changes. The full macOS suite passed with the controller-backed test host.
- Note for next time: Native focus lifecycle depends on the hosting boundary. Check a focused test in the complete app suite before treating an isolated pass or a longer delay as a fix; do not print entire NSHostingView values in failed requirements.

## 2026-09-21: Release Workspace Fixtures Before Deleting Their Vaults

- What did not work: The controller-hosting change above passed locally but did not eliminate CI failures. Isolated Markdown repetitions passed while full-suite reopening failed. Waiting for window visibility, ordering regardless of activation and disabling window animations did not fix it; replacing the product's focus task with default focus also failed and was reverted.
- What worked instead: Native responder stack traces exposed a SwiftUI NSAlert presentation, and refresh diagnostics identified retained workspaces repeatedly reading deleted fixture vaults. Add deferred `releaseWindowResources()` to `withWorkspace` before its filesystem cleanup. Retain repeated title/notes reopening and verify the native text responder after insertion; cover retained-model cleanup on both normal and throwing fixture exits.
- Note for next time: A failure in a later focus test can originate in an earlier fixture's background work. Closing a bare hosted NSWindow does not invoke the real app's workspace lifecycle cleanup. Trace the full native call stack and async errors before changing product focus behavior. Xcode 27 test iterations can repeat individual Swift Testing cases within each process as well as relaunching the process; use separate normal full-suite invocations to check cross-test isolation.

## 2026-09-21: Skill Validation Requires PyYAML

- What did not work: The skill validator failed under system Python and an existing documentation virtual environment because neither had PyYAML; `uv` was also unavailable.
- What worked instead: Create a dedicated temporary Python virtual environment, install PyYAML there, and run `quick_validate.py` with that environment's Python.
- Note for next time: Check the validator's Python dependencies first; an existing documentation environment does not imply YAML support. Keep validation dependencies outside the repository.

## 2026-09-21: Markdown Field Focus Tests In Background Windows

- What did not work: Synthetic mouse-down/up events posted through NSApp or sent directly to a background hosted window did not activate the rendered SwiftUI field reliably. Repeated coordinate/hit-test inspection still left the window's SwiftUI focus proxy as first responder.
- What worked instead: Request editing through the same binding used by Command-E, then exercise the real native source editor, text input, first-responder transfer and field-scoped outside-click handling. These establish editing/focus behavior without claiming physical click or link-activation acceptance.
- Note for next time: Background hosted-window event dispatch is not full WindowServer mouse automation. Keep synthetic click limitations distinct from a reproduced product interaction defect.

## 2026-09-21: Inline Editing In Native Reorderable Lists

- What did not work: SwiftUI simultaneous and high-priority double-tap gestures did not activate editing in the Custom-order native List. FocusState observation alone left the editor open after native first-responder loss. Looking for a SwiftUI accessibility identifier through NSView.identifier also missed the native field in hosted tests.
- What worked instead: A title-bounded local AppKit event observer receives double-clicks while passing ordinary presses/drags through. Use the TextField editing-end callback plus an outside-click observer for non-focusable destinations. Hosted tests locate the native field by its placeholder and post mouse/key events through NSApp.
- Note for next time: Validate actual double-click dispatch in both sort modes rather than testing only model activation. Return a Sendable Boolean from MainActor.assumeIsolated in local event monitors, not NSEvent. Keep physical drag acceptance distinct from hosted event tests.

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
