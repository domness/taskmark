# iOS Agent Implementation Plan

Status: planned work. Build the product specified in [IOS_SPEC.md](IOS_SPEC.md); this document supplies bounded work packets, dependencies and handoff requirements. No mobile implementation is included in the planning branch.

## Working Rules

- Start with `AGENTS.md` and its required reading. Then read the iOS spec and the assigned packet below.
- Work from `docs/ios-app-spec` or a task branch based on its latest integrated commit. Do not start independent agents from unrelated `main` snapshots.
- Before dispatching work to separate checkouts, ensure the specification and completed prerequisite packets are included in the chosen base commit. Uncommitted files in this checkout do not accompany a new worktree automatically.
- Run one packet at a time unless the dependency graph and file ownership allow parallel work. An integration owner handles shared target/public-API changes; agents must not independently edit the same extracted session files or `project.yml`.
- Preserve Mac/CLI behavior throughout. Keep schema 2 and existing module/bundle names. Do not implement unavailable platform behavior with stubs that report success.
- Before each extraction, identify current source/tests, define the narrow API and move behavior with tests. Avoid broad rewrites that make regressions hard to locate.
- Use Conventional Commits with the existing allowed scopes if asked to commit. Do not publish branches, releases or TestFlight builds without an explicit publication request.
- A packet is done only when its acceptance tests and the full currently configured `make check` pass. If required validation cannot run, report the packet as blocked with the concrete environment prerequisite. “Compiles” is not UI/iCloud validation.

## Dependency Graph

```text
IOS-01 platform + storage feasibility
   |
IOS-02 shared workspace extraction
   |---------------------------|
IOS-03 provider-safe storage   IOS-04 shared presentation/themes
   |                           |
IOS-05 lifecycle/recovery      |
   |---------------------------|
IOS-06 mobile workflows
   |
IOS-07 settings, filters, ordering and recovery UI
   |
IOS-08 interoperability, accessibility and release readiness
```

IOS-03 and IOS-04 may run independently after IOS-02 APIs are integrated, with exclusive storage versus presentation ownership. IOS-05 owns lifecycle/recovery changes to the shared session; coordinate public APIs with the integration owner. IOS-06 can prototype fixture-backed screens earlier, but is not complete until real session/storage/recovery integration passes. Add CI coverage incrementally from IOS-01 rather than leaving builds until the end.

## IOS-01 — Platform Skeleton And File-Access Vertical Slice

**Goal:** prove that the existing file model is viable on iPhone/iPad before building a complete UI.

**Own:** `Package.swift`, `project.yml`, the initial `Apps/LocalTodoIOSApp/` target/tests, build scripts/CI additions and a documented feasibility result.

**Work:**

1. Add reusable-library iOS 18 platform support, a `LocalTodoIOSApp` scheme and iOS unit/UI test targets. Link Domain/Markdown only; never embed the CLI. Use `com.domness.localtodo.ios`, Taskmark display name and iPhone/iPad device families.
2. Add native Open/Create controls with a folder document picker, iOS bookmark persistence and scoped access. A minimal fixture list is sufficient for this packet.
3. Exercise manifest read, a single revision-checked task edit and readback in a disposable local folder and externally selected iCloud folder. The final coordination/availability model belongs to IOS-03; document gaps instead of implying full support.
4. Audit platform availability of storage primitives and macOS-only APIs. Prove exclusive creation and replace/move behavior on iCloud. Record provider failure modes, placeholder/version discovery and folder creation behavior.
5. Add deterministic simulator build/test commands and CI coverage. Configure simulator tests for shared Domain/Markdown suites, excluding CLI tests that require a Mac process environment. Keep the full Mac gate.
6. Add a valid iOS icon rendition based on the current brand artwork, appropriate iOS asset metadata and required licenses. Check archive resources separately later.

**Done when:** local open/create/edit/relaunch works in Simulator; physical-device external-folder checks in spec section 9 are recorded as passed or explicitly blocked; no unsafe storage fallback is introduced; existing `make check` plus new iOS build/test stages pass. Physical iCloud feasibility is a dependency for claiming IOS-03 complete.

**Handoff:** exact schemes, test destinations, supported SDK/runtime versions, signed device commands/settings, minimal entitlements/Info.plist choices, and a list of storage gaps for IOS-03.

## IOS-02 — Extract Shared Workspace Behavior

**Depends on:** IOS-01 platform configuration.

**Own:** new `Sources/LocalTodoWorkspace/`, its tests and the Mac workspace integration. Coordinate package/project edits with the integration owner.

**Source map:**

- `Apps/LocalTodoApp/Sources/Workspace/WorkspaceModel.swift` and behavior extensions.
- `Tasks/TaskDraft*.swift`, `Collections/ProjectDraft.swift`, `Filters/FilterWorkspaceState.swift`.
- Route/query/capture, recurrence-editor values, preference projection, list-display and ordering types currently under app sources.
- Existing draft/conflict/concurrency/recovery tests under `Apps/LocalTodoApp/Tests/`.

**Work:**

1. Separate URL selection/bookmarks/session ownership from shared open/store/refresh behavior. Move AppKit clipboard/file-opening actions to the Mac shell.
2. Extract pure preference identifiers from UI projections. Keep raw validated preferences and stylesheet source/read state in Workspace; palette/CSS rendering belongs to Presentation.
3. Retain task/project/preference draft generations, session/epoch checks, per-path mutation serialization, field-specific transitions and persistence-aware Undo/Redo.
4. Move portable tests to a shared test target executed on Mac and iOS. Retain native Mac window/toolbar/focus tests in the app target.
5. Make the Mac app consume the extracted implementation before the iOS shell starts adding full features.

**Done when:** no UIKit/AppKit/SwiftUI imports in Workspace; no parallel Mac/mobile implementations of draft or mutation behavior; existing Mac tests pass and shared tests execute on both platforms. In particular preserve `WorkspaceCaptureConcurrencyTests`, `SharedPreferenceConcurrencyTests`, project/filter conflict coverage and delayed-write/recovery behavior.

**Handoff:** public session/action/state API, lifecycle hooks for IOS-05, UI state ownership, relocated tests and any platform-specific code intentionally retained.

## IOS-03 — Provider-Safe Storage And iCloud Availability

**Depends on:** IOS-01 evidence and IOS-02 session boundary.

**Own:** `Sources/LocalTodoMarkdown/`, storage tests/fixtures, provider availability/conflict state exposed to Workspace, and corresponding canonical architecture/file-contract documentation.

**Work:**

1. Extend the existing filesystem boundary for coordinated reads, coordinated exclusive creation, availability/partial enumeration and provider versions. Keep metadata concerns out of Domain task semantics.
2. Audit every entity/config/filter/stylesheet path, including reads inside mutations, initializers, duplicate/delete/restore and task moves. Preserve exact-path coordination, revisions and atomic publication; test cancellation/remapped URLs and avoid nested-coordination deadlocks.
3. Represent unavailable versus confirmed-missing files and scan completeness. Retain known unavailable records as stale UI data without treating them as writable records; block operations needing complete reference knowledge.
4. Implement bounded materialization and coalesced change observation. Directory presenters and provider-version callbacks must have explicit queues, lifetime and foreground/background registration hooks.
5. Expose unresolved versions for entities and metadata, with revision/version-set-checked explicit resolution and recoverable alternatives. Never auto-delete conflict copies or versions.
6. Supply fake provider/coordination boundaries for deterministic delayed-download, failure, conflict and external-change tests. Add a repeatable physical iCloud exercise using a synthetic vault.

**Done when:** A01–A06 pass at the model/storage level; on-device tests prove no unsafe fallback; a missing `.config/` item cannot be overwritten by defaults; partial scans cannot enable unsafe collection deletion. Mac/CLI behavior and diagnostics remain valid through the shared API changes.

**Handoff:** availability/scan-completeness model, resolution API and invariants, presenter ownership, provider capability limits and actual physical-device evidence.

## IOS-04 — Shared Themes And Native Presentation Primitives

**Depends on:** IOS-02 preference/session API. May run alongside IOS-03 with separate file ownership.

**Own:** new `Sources/LocalTodoPresentation/`, presentation tests, shared font resource packaging, Mac presentation adaptation and mobile typography bridge.

**Source map:** `Settings/AppTheme.swift`, `ThemeTypography.swift`, `AppAppearanceModifier.swift`, `ThemePreview.swift`, `Workspace/VaultAppearance.swift`, `Tasks/TaskMarkdown*.swift` and `Apps/LocalTodoApp/Resources/Fonts/`.

**Work:**

1. Share palette definitions, CSS parsing and override precedence without copying token tables into iOS.
2. Split token values/parsing from SwiftUI color/font projection and platform typography. Ensure Workspace does not depend on Presentation.
3. Implement spec section 6 mobile defaults and exact explicit token semantics, with Dynamic Type scaling exactly once. Retain Mac sizing.
4. Package one source of font resources/licenses for both apps and test family/weight/italic availability. Update resource/documentation paths if assets move.
5. Share rendered Markdown primitives where useful; keep AppKit editing boundaries and UIKit editing boundaries separate. No web view or source serialization through attributed text.
6. Supply fixture previews/tests for palettes, stylesheet fallback, unknown/invalid declarations, appearance-specific tokens, reduced transparency and large type.

**Done when:** A10/A11 presentation tests pass; Mac typography tests continue to pass; all six themes and CSS overrides are visible in phone/tablet fixtures; core controls retain native accessibility behavior. Update `DESIGN.md`, `docs/THEMES.md` and `docs/PERSONALIZATION.md` to describe the actually implemented platform mappings.

**Handoff:** theme/token API, resource registration, platform sizing policy and screenshots with device/appearance/text-size labels.

## IOS-05 — Mobile Session Lifecycle And Draft Recovery

**Depends on:** IOS-02 and IOS-03.

**Own:** iOS session composition, bookmark/access lifetime, lifecycle bridge, app-local recovery persistence adapter and shared session recovery behavior/tests.

**Work:**

1. Wire scene activation/backgrounding to refresh, polling, presenter registration and bounded save completion. Handle expiration, protected-data unavailability and access revocation.
2. Implement the spec's device-local checkpoint format and state machine for task/project/preference/capture/filter drafts. Document its versioning and generation/reconciliation rules; it is not vault schema or a canonical database.
3. Recover only after restoring/validating the correct vault. Resolve current revisions before offering/applying drafts; recognize canonical success followed by interrupted checkpoint cleanup.
4. Preserve invalid/conflicting/offline drafts through dismissal and termination. Model explicit discard and storage-full failures.
5. Keep one mobile scene/session; make vault switching flush or retain recoverable changes and release resources only after in-flight access completes.

**Done when:** A07/A08 pass with deterministic lifecycle and fault injection. A delayed save followed by new typing, suspension, vault switching or restart cannot publish stale data. Capture is never duplicated and recurrence never advances twice during recovery.

**Handoff:** state-transition summary, durability window, checkpoint location/lifetime/backup policy, pending-changes API for mobile screens and background-device test results.

## IOS-06 — Adaptive Daily-Work UI

**Depends on:** IOS-02, IOS-04 and IOS-05 integrated; uses IOS-03 availability states.

**Own:** iOS navigation, task lists, capture, details, planning/organization, project/area workflows, mobile UI tests and previews.

**Work:**

1. Implement Today/Inbox/Browse/Search navigation and iPad split layout with stable session-owned drafts and exact-path selection. Honor all startup-route values.
2. Wire title-first contextual capture, task completion/editing, read-first Markdown, checklist toggles, recurrence/reset and paired-date rescheduling to shared actions.
3. Add native compact date controls, tags, project/area/priority/status controls, creation/project editing, inactive-project review and protected collection deletion.
4. Expose duplicate/delete/copy/share and explicit Undo/Redo. Preserve native text-editor keyboard behavior. Support menu/button alternatives to swipes and drags.
5. Make save/availability/conflict states visible outside collapsed file details. Keep unsaved drafts reachable after tab/route changes.
6. Test iPhone portrait/landscape and iPad narrow/wide transitions, native keyboard focus, VoiceOver actions and accessibility text layouts.

**Done when:** A09/A12 workflow cases pass against a real temporary vault, not only mocks; all required daily workflows can be performed by touch and accessibility actions; no source text is rewritten by rendering.

**Handoff:** screen/navigation map, fixture previews/screenshots, tested input paths, UI automation results and remaining physical-gesture checks.

## IOS-07 — Personalization, Filters, Ordering And Recovery Surfaces

**Depends on:** IOS-06 and all shared infrastructure.

**Own:** mobile Settings/Vault Status, combined/saved filter screens, view options/reorder controls, issue/conflict/recovered-draft screens and UI tests.

**Work:**

1. Implement every shared setting in the spec; retain unsupported/unknown keys, including Mac `dock_badge`, during edits. Add theme previews, stylesheet enablement/reload and diagnostics.
2. Implement combined filters and explicit named-filter Save/Update/Delete with whole-document conflict resolution.
3. Honor and edit existing route keys, grouping/metadata options and manual orders. Provide native edit/reorder and accessible Move Up/Down, respecting group boundaries and hidden item positions.
4. Implement current-file/local-draft conflict choices, provider-version review/recovery, preference conflicts, unavailable-file retry and Locate Vault. Revalidate on submission; expose conflicts that appear during resolution.
5. Show local-save versus provider-delivery status and last refresh without claiming guaranteed synchronization.

**Done when:** A03/A05/A06/A10–A12 pass end to end; edits interoperate with Mac/CLI and never rewrite absent defaults just by opening Settings; invalid styles fall back with visible diagnostics; recovered drafts have a usable apply/discard/export path.

**Handoff:** completed feature matrix, metadata round-trip fixtures, conflict-resolution evidence and a list of manual iCloud cases ready for IOS-08.

## IOS-08 — Cross-Device Acceptance And Distribution Readiness

**Depends on:** IOS-01–IOS-07.

**Own:** test matrix/results, CI integration, performance/accessibility fixes within agreed scope, documentation and signing/archive readiness.

**Work:**

1. Run the full A01–A13 matrix and the physical-device sequence in spec section 8. Record failures/not-run cases explicitly; add regression tests before fixes.
2. Verify minimum iOS 18 and current supported OS, phone/tablet, local/iCloud storage, offline/reconnection, large type, VoiceOver, keyboard and six themes in both appearances.
3. Measure cold/warm local-vault open, foreground rescan, capture acknowledgement and scrolling on a named physical device with a synthetic 1,000-task vault. Target warm list availability within 1 second and local capture persistence within 500 ms under ordinary local-storage conditions; report measured results, excluding cloud download time. Profile UI blocking or unbounded background work before optimizing; do not add a canonical database to meet a target.
4. Ensure `make check` includes all shared/iOS/Mac tests and builds, with explicit simulator selection and saved `.xcresult`/logs. Confirm GitHub-hosted CI can reproduce the gate.
5. Validate signed device installation and an iOS archive suitable for TestFlight: bundle ID, icon, fonts/licenses, entitlements and resource resolution. Record distribution setup without credentials. Upload only in a separately authorized release task.
6. Update `docs/ROADMAP.md` from planned to implemented only for completed behavior; keep real-device/manual gaps visible. Align architecture, file-format, themes and user docs with shipped behavior.

**Done when:** automated gate is green, required physical iCloud data-preservation/recovery cases pass, acceptance limitations are documented and a signed archive is validated. Public App Store release is a separate decision.

## Copy-Ready Agent Prompt

Replace the packet ID and base branch/commit before dispatching:

```text
Implement IOS-XX from docs/IOS_IMPLEMENTATION.md, following docs/IOS_SPEC.md.
Base: <integrated branch and commit>. Complete only this packet and its required
integration/tests. Read AGENTS.md and all required project guidance first.

Inspect current source before editing; predecessor agents may have moved files.
Preserve schema 2, exact path identity, unknown YAML/body data, shared config/theme
semantics and existing Mac/CLI behavior. Reuse extracted session/storage behavior;
do not fork it into an independent iOS implementation.

Honor the packet's ownership/dependencies. If a prerequisite is absent or a
provider cannot meet the storage contract, report the concrete blocker rather
than adding a success stub or unsafe fallback. Coordinate shared target/API edits
with the integration owner before changing another packet's interface.

Add meaningful behavior/fault-injection tests and run make check, including the
iOS checks available at this stage. Record Xcode version, simulator/device/OS,
commands and results. Distinguish model/build/UI/physical-iCloud evidence.

Return the handoff below. Do not push, publish, or start other packets unless asked.
```

## Required Handoff

```text
Packet and status:
Base and resulting commit (or uncommitted files):
Implemented behavior and source paths:
Public APIs / target or resource changes:
Acceptance IDs covered, with test names:
Xcode, SDK, runtime, simulator/device and commands:
make check result:
UI / accessibility / physical iCloud evidence:
Known failures or not-run cases:
Dependencies / next packet:
```
