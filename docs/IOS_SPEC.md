# Taskmark For iPhone And iPad

Status: implementation specification, not implemented. Prepared 2026-09-24 against the repository on branch `docs/ios-app-spec`.

The agreed platform scope is **iPhone and iPad, iOS/iPadOS 18+**. The implementation sequence and copy-ready agent instructions are in [IOS_IMPLEMENTATION.md](IOS_IMPLEMENTATION.md).

[Mobile screen mockups](design-exploration/ios/README.md) illustrate the proposed Today, task detail, capture, Browse, theme, vault-status and iPad screens. They are visual references using synthetic content, not native implementation or accessibility-validation evidence.

## 1. Outcome

Make Taskmark a dependable native mobile client for the **same Markdown vault** used by the Mac app and `taskmark` CLI. A user opens their existing iCloud Drive folder on their phone, sees their tasks and personalizations, captures and completes work, and sees those changes on their Mac when iCloud delivers them. A local vault also works without iCloud or an account.

Mobile V1 is a daily-use client, including task editing, planning, projects/areas, search, saved filters, themes and configuration. Its controls adapt to touch and compact screens while its file and task semantics remain shared.

### Success criteria

- One schema-2 vault opens and round-trips between macOS, iOS and CLI without conversion, import copies, path changes or metadata loss.
- Capture, completion, recurring tasks, checklists, dates and organization work on iPhone and iPad, including offline when the required files are available locally.
- Shared configuration, all six themes, bundled fonts, saved filters, custom ordering and supported stylesheet tokens work on mobile.
- External changes, unavailable files, conflicts and unsaved drafts have explicit, recoverable states.
- The Mac app and CLI retain their existing behavior and pass their full quality gate throughout extraction.
- Automated checks and actual Mac-to-iPhone/iPad iCloud tests provide separate evidence. Simulator success alone is insufficient to claim iCloud interoperability.

### Scope boundary

Use SwiftUI with small UIKit integrations for platform capabilities. The mobile product has no embedded CLI, shell installer, Taskmark account, CloudKit task database or custom synchronization transport. Widgets, Share extension, App Intents, reminders, collaboration, web, rich-text serialization, full multi-window iPad support and arbitrary third-party-provider certification are later work. Keep existing project/area path moves disabled.

## 2. Repository Baseline And Gaps

These paths exist today; proposed targets in section 3 do not.

| Existing implementation | Reuse / gap |
| --- | --- |
| `Sources/LocalTodoDomain/` | Shared entities, dates, recurrence, query and transition semantics; already UI-independent. |
| `Sources/LocalTodoMarkdown/` | Shared codecs, revisions, storage, configuration and saved filters. Audit every filesystem operation for iOS and document-provider behavior. |
| `Package.swift` | Currently declares macOS 15 only; add iOS 18 support to reusable libraries and simulator test coverage. |
| `project.yml` | Currently macOS app, CLI and app-test targets only; this is the source for generated Xcode changes. |
| `Apps/LocalTodoApp/Sources/Workspace/WorkspaceModel*.swift` | Substantial reusable draft, autosave, query, conflict, ordering and history logic, coupled to desktop routing, vault picking and lifetime. Extract rather than fork. |
| `Apps/LocalTodoApp/Sources/Vault/` | AppKit picker and macOS bookmark options; iOS needs its own picker/bookmark adapter and access-failure handling. |
| `Apps/LocalTodoApp/Sources/Settings/` and `Workspace/VaultAppearance.swift` | Six palettes, preference projection and bounded CSS parser; typography and some settings controls use AppKit. |
| `Apps/LocalTodoApp/Resources/Fonts/` | Existing Inter/Figtree font resources and licenses; reuse the same font assets. |
| `FoundationVaultFileSystem+Coordination.swift` | Implements coordinated writes and moves. `VaultFileSystem` has no coordinated-read API; `read(at:)` currently uses `Data(contentsOf:)`. |
| `VaultStore.swift` / `VaultScanner.swift` | Full scans and exclusive creation exist, but plain existence/enumeration/read results are not a complete provider-availability model. Entity creation currently publishes exclusively without a surrounding coordinator call. |
| `WorkspaceModel.swift` refresh loop | Approximately two-second full scans; iOS needs foreground-aware scheduling and suspension handling. |

**Meaning of existing iCloud support:** the app can work with a user-selected synchronized folder and has coordinated mutation primitives. There is no dedicated sync engine, configured app-owned iCloud container, download-state model, file presenter or `NSFileVersion` conflict workflow in the current code. The roadmap still calls for real-device iCloud validation. Mobile work must close these gaps instead of treating current file coordination as proof of complete sync behavior.

## 3. Proposed Architecture

Preserve the existing module names, Mac bundle identifier and dependency direction. Introduce two focused app-layer libraries through staged extraction; do not move UI or application lifecycle into Domain or Markdown.

```text
LocalTodoApp (macOS)             LocalTodoIOSApp (iOS/iPadOS)
       |                                  |
       +--------> LocalTodoPresentation <-+
       |                    |
       +--------> LocalTodoWorkspace <----+
                            |
                 LocalTodoMarkdown <-------- LocalTodoCLI
                            |                     |
                     LocalTodoDomain <------------+
```

Both app-layer libraries may use Domain values directly. `LocalTodoPresentation` may use Workspace APIs; Workspace must not depend on Presentation. All vault reads/writes go through Markdown APIs.

| Planned target / location | Responsibility |
| --- | --- |
| `LocalTodoWorkspace`, `Sources/LocalTodoWorkspace/` | Foundation/Observation app-session state: snapshots, task/project drafts, autosave, conflict/recovery state, preferences, filters, ordering and persisted-action history. No SwiftUI, AppKit or UIKit. |
| `LocalTodoPresentation`, `Sources/LocalTodoPresentation/` | Shared SwiftUI presentation primitives: palette definitions, token parsing/application, Markdown rendering and reusable controls where interaction genuinely matches. Separate platform typography bridges are allowed. No filesystem mutations. |
| Existing `LocalTodoApp` | Mac scenes, toolbar, inspectors, window lifecycle, commands, Dock badge, picker, bookmarks, Finder/pasteboard integration and CLI installation. |
| `LocalTodoIOSApp`, `Apps/LocalTodoIOSApp/` | iOS composition, adaptive navigation, picker/bookmarks, scene lifecycle, touch editors, sharing/copying and device-local recovery storage adapter. Product display name: Taskmark. |
| Existing `LocalTodoMarkdown` | File availability/coordination, provider-version access, canonical persistence and diagnostics on both platforms. |

Use the planned iOS bundle identifier `com.domness.localtodo.ios`; verify signing-account availability during device setup. Never change `com.domness.localtodo` to enable mobile. Shared source extraction does not justify making all existing implementation types public: expose narrow session/action/state APIs.

### Extraction rules

1. Move working behavior with its regression tests, then adapt consumers. Do not independently reimplement recurrence, draft rebasing, preference writes or undo in the phone app.
2. Separate pure preference identifiers from SwiftUI colors/icons/fonts. Workspace can publish stylesheet source/read status; Presentation owns CSS validation and native projection, avoiding a dependency cycle.
3. Platform shells select URLs and own security-scoped access. The shared session receives an accessible root/store, injected clock and lifecycle requests. Foundation `UndoManager` can remain injected at this boundary.
4. Clipboard, external-file opening, keyboard focus, native text editing and window/scene lifetime stay in platform adapters. Inject closures or small protocols only at actual boundaries.
5. Keep vault-session IDs, model epochs, draft generations and per-path reservations. Cancelled/stale work cannot publish into another vault or a newer draft.
6. Share palette data and parsing once. Share UI only where useful; the macOS toolbar and iPhone task screen are separate compositions.
7. Use Swift 6 complete strict concurrency. Off-main storage/coordination work must not block UI; design presenter callbacks so they cannot deadlock against the store actor or main actor.

## 4. Vault Access And iCloud Drive

### Onboarding and vault ownership

Offer **Open Existing Vault** and **Create Vault**. Explain that choosing an iCloud Drive folder makes the vault available to other devices signed into that iCloud account; the entire folder, including hidden `.config/`, is required.

- Open a folder through the native document picker (`UTType.folder`, open-in-place rather than copy/import). The Mac and phone must edit the same selected folder, not separate mirrored app copies.
- Create by selecting/creating an empty folder in Files, then running the shared initializer. Support writable local Files locations as well as iCloud Drive. Never initialize an existing nonempty folder or reinterpret a temporarily unavailable manifest as a new vault.
- Do not require an app-owned ubiquity container. Capability/Info.plist settings must follow the proven external-folder access path; do not invent a container identifier or add CloudKit to solve picker access.
- Retain a security-scope lease for the full session and all in-flight I/O. Balance successful start/stop calls; distinguish sandbox-local URLs from denied external URLs.
- Save device-local bookmark data using iOS-supported options (Apple's directory-access example uses `.minimalBookmark`, not the Mac `.withSecurityScope` implementation). Resolve on launch, refresh stale bookmarks after successful access, and offer **Locate Vault** when access is revoked or resolution fails.
- One active vault per mobile scene, with one supported scene in V1. Provide Switch Vault and restore the last successfully opened bookmark. Complete or preserve pending edits before switching; never associate a recovered draft with another folder merely because its name matches.
- Opening/picking cancellation keeps the previous usable workspace. A failed open must not discard it.

### Availability and coordinated I/O

Add explicit availability information at the storage boundary: locally readable, downloading/materializing, unavailable/error, and confirmed missing. Enumeration may be incomplete. Do not infer deletion from a missing `fileExists` result or a partial provider scan.

- Coordinate reads of entities, manifest, saved filters and stylesheet, and coordinate creation, replacement, deletion and moves at their exact affected URLs. Reads performed inside an existing coordinated mutation must not recursively reacquire coordination in a deadlocking way.
- Preserve the existing symlink/path validation, revision comparisons, exclusive creation and atomic replacement. Audit `renameatx_np`, replacement and temporary-file behavior on the actual iCloud provider; an unsupported atomic operation must fail explicitly rather than fall back to unsafe copy/delete.
- Request iCloud materialization through supported Foundation APIs when the URL is ubiquitous; use provider-supported coordinated access for other providers. Query URL metadata where available. Provider status may be unknown; do not fabricate progress percentages.
- Download the manifest first. Discover typed-file candidates and metadata with bounded work; `.config/` is excluded from entity scans but explicitly read for configuration, filters and stylesheet. Avoid hidden-file filtering that loses metadata or provider placeholders.
- On a first partial scan, show available tasks with a visible incomplete-vault state; on later partial scans, retain last-known rows as unavailable/stale, not editable canonical records. Unknown tasks need a vault-level availability message, not invented titles or placeholder identities.
- Counts, reference diagnostics and empty states must indicate incomplete data. A not-yet-loaded collection is distinguishable from a confirmed broken reference.
- Block edits to unavailable files. Block reference-sensitive actions such as collection deletion when a complete reference scan cannot be obtained. Never prune shared ordering/preferences solely because a file is temporarily absent.
- Read-only or unavailable folders expose actionable errors and Retry/Locate Vault; they do not become blank writable vaults.

### Refresh and lifecycle

Use a session-owned directory file presenter for coordinated changes, coalesced into refresh requests, plus foreground refresh/pull-to-refresh and a bounded foreground polling fallback for uncoordinated external editors. Presenter notifications alone do not observe every possible writer.

- Refresh immediately on foreground entry and after successful local mutations. Reevaluate Today when the vault-local day changes, including after a timezone change or suspension.
- Pause polling/download retries when backgrounded. Remove file presenters before suspension and re-register on foreground, as required by Apple's coordination guidance. Balance registration on vault switch and session release as well.
- Coalesce refreshes and cap concurrent materialization. Cancel stale queued work; do not hold directory coordination across network waits or the entire UI session.
- Use bounded background time to finish already-started saves/checkpoints, handling expiration and cancelled coordination. Background execution and iCloud upload completion are not guaranteed.

### Conflict handling

There are two independent conflict mechanisms:

1. **Taskmark revision/draft conflicts:** retain current three-way behavior. Non-overlapping field edits rebase; same-field edits and calculated transition dependencies require explicit resolution. Preferences rebase different top-level fields; saved-filter document writes retain whole-file optimistic concurrency.
2. **Provider versions/conflict copies:** inspect supported `NSFileVersion` unresolved versions and report them separately from draft conflicts. Include entity files and `.config/` metadata. File coordination on one device does not serialize offline writers on different devices.

Provide a Conflict detail surface with exact path, current content, recoverable alternative content and explicit choices. Revalidate the file revision/version set immediately before resolution. Make recovery/export of alternatives available before any destructive version cleanup; mark only the versions actually resolved after the chosen bytes are successfully persisted. A racing resolution on another device must refresh/retry rather than remove an unseen version.

Do not automatically merge an unknown-base provider conflict, choose a timestamp winner, remove a conflict copy, or repair invalid YAML. Visible conflict-copy files retain their exact-path identities and appear in diagnostics/review; do not deduplicate by title. Provider capabilities and undisclosed remote changes limit what the app can detect: do not promise globally serialized edits or guaranteed automatic merging of offline changes.

### User-visible save and availability status

Distinguish **Saving…**, **Saved to vault**, **Waiting for file**, **Download failed**, **Unsaved changes**, **Conflict**, and **Access required**. Show upload/download state only when supplied by the provider. “Saved to vault” means the local coordinated write completed; it does not mean another device has received the change. Show last successful refresh and Retry in Vault Status. Avoid an unconditional “Everything synced” badge.

## 5. Mobile Workflows And Navigation

### iPhone / compact width

Use four native destinations: **Today**, **Inbox**, **Browse**, **Search**, each with a `NavigationStack` and preserved local navigation state. Browse contains Next, Upcoming, Waiting, Someday, All Tasks, projects, areas, tags, priorities and saved filters. Keep Inbox ahead of Today within any combined built-in list, matching desktop ordering.

- Honor every existing `initial_view` value: Today/Inbox/Search select their destination; Next/Upcoming/Waiting/Someday/All select Browse and open that route. Do not rewrite the preference to match the tab set.
- Task row tap pushes task details in reading mode. Completion is a separate, labeled touch control. No double-tap requirement for ordinary editing.
- A consistent native **Add Task** toolbar action opens focused quick capture from every task route. One tap reaches title entry; submitting a title uses existing contextual capture defaults.
- Browse exposes Settings and Vault Status. A visible issue indicator leads to diagnostics from task lists when attention is needed.
- Native context menus and non-full-swipe actions expose reschedule, duplicate, organization and delete. Every gesture has a discoverable menu/button and VoiceOver equivalent. Deletion offers session Undo without relying on shake gestures.
- Navigating away retains the session-owned draft and autosave state. Invalid/conflicting drafts remain reachable from an **Unsaved Changes** surface even when the edited task leaves the current query.

### iPad / regular width

Use a native adaptive `NavigationSplitView`: navigation sidebar, task list and selected-task detail when space permits. Narrow Split View/Stage Manager sizes collapse to list/detail navigation rather than enforcing desktop minimum widths. Preserve route, selection and draft identity through rotation and size-class changes.

Support touch, pointer and hardware keyboard for capture, search, completion, editing and Undo/Redo. Reuse familiar desktop shortcuts where suitable. Keyboard delete actions must never intercept Backspace inside an editor. Drag/drop for task organization is an enhancement after menu-based organization and reorder controls work reliably; V1 custom ordering itself is required.

### Required feature coverage

| Area | Mobile V1 requirement |
| --- | --- |
| Lists | All existing built-in/collection/tag/priority routes, shared Today/Upcoming semantics, completion visibility, grouping and automatic sorts. |
| Capture | Title-first sheet, contextual defaults, optional notes/planning/organization, collision-safe paths and protection against duplicate submission. Cancel explicitly discards an unsaved new-task draft. |
| Details | Rendered-first title/Markdown notes; tap or Edit reveals source. Completion next to title; Planning and Organization remain directly available. File details collapsed; pending saves/problems always visible. |
| Planning | Scheduled/deadline date pickers, suggestions and exact ISO entry; status, priority and paired-date reschedule use shared rules and vault timezone. |
| Recurrence | Fixed and after-completion rules, interval/weekdays, repeat checklist-reset choice; completion advances once using the latest valid draft. |
| Checklists | Toggle recognized markers only; retain exact unrelated body bytes and offer source editing for unsupported Markdown. |
| Organization | Project, area and tags including suggested existing tags; preserve case and tag strings containing commas. |
| Collections | Create project/area, browse associated tasks, edit project title/notes/status, complete/reopen project, show inactive projects; protected non-cascading collection deletion. Additional area editing beyond desktop parity is later work. |
| Search / filters | Search and combined filters use Domain queries; create/run/update/delete named saved filters through `.config/filters.md`, with explicit save and document-conflict handling. |
| Ordering | Read/write existing `sidebar_order`, `custom_order` and `views` using identical route keys. Native edit/reorder mode plus accessible Move Up/Down; preserve hidden items and same-group restrictions. |
| File actions | Duplicate/delete/Undo, copy title/Markdown/exact relative path and platform share/export. Share a copy does not switch the vault or change identity. Finder-specific actions become appropriate native mobile actions. |
| Recovery | Malformed files, missing references, stale drafts, read-only/unavailable files, preference/filter conflicts and provider conflicts have paths, explanations and recovery actions. |

Only successful persisted actions enter domain-action history. Keep native text-editor history distinct from persisted-action Undo. Exact-byte deletion recovery remains local to the active session; present its lifetime honestly, and never restore over an occupied path.

## 6. Shared Configuration, Themes And Accessibility

The canonical preference/stylesheet contract remains [FILE_FORMAT.md](FILE_FORMAT.md), [PERSONALIZATION.md](PERSONALIZATION.md) and [THEMES.md](THEMES.md). Mobile introduces no schema bump or mobile-specific copy of configuration.

| Shared data | iOS behavior |
| --- | --- |
| `appearance` | System follows the device; explicit Light/Dark applies at every scene and sheet root. |
| `theme` | Same stored identifiers and paired colors: Taskmark, Slate, Forest, Sand, Catppuccin Latte/Mocha, Dracula Alucard/Dracula. |
| `vault_stylesheet` | Same shared enablement; existing allowed selectors/tokens, source-order precedence, 64-KiB UTF-8 limit and rejection/fallback rules. Read-only source file. |
| `timezone`, `week_start`, `date_format`, `time_format` | Shared choices applied to dates/calendars; ISO persistence and recurrence semantics unchanged. |
| `initial_view` | Map to adaptive navigation as described above, including routes under Browse. |
| `views`, `sidebar_order`, `custom_order` | Same exact keys and paths, adapted to native mobile controls. |
| `.config/filters.md` | Same document and behavior as Mac/CLI, including unknown fields and body preservation. |
| `dock_badge` | Preserve without displaying/editing on iOS. It does not grant notification permission or enable an iOS app-icon badge. |
| Unknown root/nested keys | Preserve on all known-field writes; never serialize an iOS-only preference subset over the full manifest. |

Settings has General, Theme and Vault sections using native mobile navigation. Include appearance/palette previews, stylesheet enablement/reload/diagnostics, calendar/display/startup/timezone settings, vault location, access/status and Switch Vault. Settings states belong to the active session; presenting/dismissing the sheet cannot abandon preference drafts. CLI registration and Mac window/Dock controls are not mobile settings.

### Typography and token adaptation

This is a planned platform adaptation, not a change to the implemented Mac typography:

- Default mobile body base is **17 pt**, or **18 pt for Catppuccin**, at the default Dynamic Type category; Mac defaults remain 13/14 pt. Keep the same family selection: SF, Inter or Figtree.
- An explicit `--task-font-size` remains an **11–24 logical-point base** at the default content-size category, on both platforms. On iOS it scales through semantic Dynamic Type metrics exactly once. Do not reinterpret a user-supplied 14px as 18pt or write platform defaults into `style.css`.
- `--row-spacing` remains 2–16 logical points between title and metadata. Row height expands to fit content and touch targets independently of this token.
- Share one set of font assets/licenses; register iOS bundle fonts with supported `UIAppFonts` entries and validate regular/bold/italic resolution offline.
- Map `--background` to task-list/Settings content, `--sidebar-background` to Browse/sidebar navigation content, and `--inspector-background` to task/project details. Sheet editors inherit the appropriate semantic surface. System-owned menus/pickers keep platform semantics.
- Native text, selection, focus and disabled behavior remain authoritative. No CSS engine, remote fonts, web view, arbitrary layout CSS or remote Markdown images.

Use the focused-canvas hierarchy: opaque task content, restrained semantic color, notes before metadata, no nested decorative cards or colored side stripes. System glass is limited to appropriate navigation/control surfaces on iOS 26+ with native accessibility behavior and iOS 18 fallbacks.

All core actions require VoiceOver labels/actions, visible external-keyboard focus, non-color state cues and at least 44×44-point touch targets. Support all accessibility text sizes, Bold Text, Reduce Motion, Reduce Transparency and Increase Contrast. At large text sizes, stack metadata/property rows and allow scrolling/wrapping rather than clipping task titles or shrinking controls. Test contrast across all built-in palettes; report invalid stylesheet syntax without silently rewriting user colors.

## 7. Draft Durability And Mobile Suspension

The Mac app can defer closing/quitting; iOS cannot depend on that. Shared task/project/preference drafts must survive view dismissal, tab changes and interrupted saves. Use debounced canonical autosave plus a device-local recovery checkpoint for uncommitted edits, including quick capture and unsaved filter editing.

- A checkpoint records the vault bookmark association, exact relative path or new-capture intent, base revision/needed merge values, local edited fields and generation. It is recoverable user input, **not a task database, sync queue or disposable snapshot cache**.
- Store it atomically in app-local Application Support with appropriate file protection, outside the vault and excluded from backup. It must not travel through `.config/` or become entity identity. Any device-local identifier is only a bookmark/session association.
- Checkpoint on a short debounce while editing and flush on background transition. Define and test the maximum normal debounce interval (target at most one second). An abrupt termination can lose input newer than the last completed checkpoint; never report that input as saved.
- Distinguish “draft recovered on this device” from “saved to vault.” After restart, resolve the correct vault, reread the current file and rebase/resolve conflicts before applying a checkpoint. Never blindly replay completion/recurrence/deletion commands.
- If canonical persistence succeeded but checkpoint cleanup did not, recovery recognizes the already-applied state and does not duplicate captures or advance recurrence again. New captures record a stable intended path and expected published content for reconciliation; path occupation is a conflict, not permission to overwrite.
- Remove a checkpoint only after its generation is persisted or the user explicitly discards it. Invalid drafts and access-denied drafts remain recoverable. A storage-full/checkpoint error is visible and does not masquerade as successful autosave.
- Inject lifecycle/clock/storage boundaries in tests. Background expiration cannot clear drafts, mark writes successful or leak security access/presenter registration.

## 8. Acceptance And Release Evidence

### Automated acceptance matrix

| ID | Scenario and required result |
| --- | --- |
| A01 | Mac/CLI schema-2 fixture opens on iOS; known-field edits preserve unknown root/nested YAML values, body bytes and exact-case paths. No migration. |
| A02 | New local/iCloud folder initializes exclusively; existing/nonempty/malformed/unavailable vaults are never reinitialized. Cancel/failure retains the previous session. |
| A03 | Missing/download-pending manifest, entity, stylesheet or filters show correct availability; partial enumeration does not delete rows, reset preferences, claim a complete empty view or allow unsafe collection deletion. |
| A04 | Delayed/failed coordination, provider remaps, cancelled materialization, stale revisions, occupied destinations, symlinks and unsupported atomic rename leave canonical data intact and errors actionable. |
| A05 | Different-field edits rebase; same-field and recurrence/checklist dependency conflicts require resolution. Preferences and filters preserve their documented concurrency rules. |
| A06 | Provider-version changes during resolution preserve new versions; conflict copies are not silently deleted/deduplicated. Alternative recovery content survives a failed resolution. |
| A07 | Background/foreground, access revocation, stale bookmark, vault switch and session release balance access/presenters and reject stale async publication. |
| A08 | Termination after checkpoint, during save and after save-before-cleanup restores/reconciles drafts without duplicate capture or repeated calculated transitions. Recovery never attaches to a different vault. |
| A09 | Today/Upcoming, recurrence, paired dates, checklists, search/filters and ordering match Mac/CLI fixtures using injected calendar/timezone/clock, including DST and midnight. |
| A10 | Shared preferences/theme/style changes reload both directions. Same route keys/order apply; unknown fields and `dock_badge` survive iOS edits. Merely opening iOS does not rewrite defaults. |
| A11 | All six themes, both appearances, stylesheet precedence/disable/failure, font resources and semantic size scaling work in workspace, detail, settings and sheets. |
| A12 | Phone navigation and iPad collapse/expand preserve drafts/selection; startup routes work; capture, edit, complete, reschedule, reorder, delete/Undo and conflict recovery are accessible. |
| A13 | Existing full Mac/CLI gate passes; iOS shared-library/model tests and phone/tablet UI tests pass on configured simulator destinations. |

Use Swift Testing for model/storage behavior and XCTest for UI automation. Move existing portable tests with extracted logic; retain AppKit-hosted tests in the Mac target. Add regression tests before fixing any reproduced defect. Use temporary synthetic vaults, injected failures and readiness predicates, not real user vaults or arbitrary sleeps.

### Required physical-device interoperability run

Use a disposable test vault on a Mac and signed iPhone/iPad apps sharing an iCloud account. Record OS versions, app commit/build, device types and results without account identifiers or personal vault content.

1. Create on Mac; open the same folder in mobile Files. Verify nested entity paths and all hidden metadata, fonts/themes, filters and ordering.
2. Create, edit, complete/repeat and toggle checklists in each direction; verify exact on-disk content and CLI queries after delivery.
3. Change theme, timezone, view options, ordering and saved filters in each app. Edit `style.css` with an external file editor and verify both apps reload it without a relaunch. Verify unknown-key preservation throughout; Taskmark itself never writes the stylesheet.
4. Download required files, go offline, edit on both devices, reconnect and inspect both non-overlapping and overlapping changes/provider versions. Demonstrate explicit recovery where automatic rebase is not possible.
5. Exercise Files “Remove Download”/materialization, unavailable manifest, poor connectivity, iCloud unavailable/signed out, read-only access and revoked folder access. No false empty vault, preference reset or silent data loss.
6. Background during typing and during writes; relaunch after termination; verify checkpoint recovery and single recurrence advancement. Move/rename the vault externally and exercise bookmark recovery.
7. Exercise iPhone portrait/landscape, iPad narrow/wide multitasking, hardware keyboard, VoiceOver, accessibility text sizes and light/dark/contrast combinations.

Track each case as passed, failed or not run. iCloud delivery has no promised fixed latency; record observed convergence/timeouts and unresolved states rather than inventing a global sync-complete signal. A failed data-preservation/recovery case blocks mobile release.

### Build and distribution

Add explicit phone/tablet simulator build/test targets and extend `make check` so the complete gate includes iOS once the target lands. Select installed simulator destinations explicitly and fail clearly if a required runtime is missing. Shared Domain/Markdown/Workspace tests must execute on iOS, not merely compile indirectly in the app. Keep Mac/CLI tests and release-script checks.

Support an iOS 18 runtime and a current supported runtime in the validation matrix; newer-only APIs need availability checks. Configure GitHub-hosted CI with pinned Xcode/runtime choices, simulator results and logs. Verify the current `macos-15` / Xcode 26.3 workflow's installed runtimes rather than assuming parity with local Xcode 27.

First distribution milestone is a signed device build/TestFlight candidate. Document signing, bundle ID, app icon, font/license resources and App Store archive validation separately from simulator checks. Do not reuse macOS Developer ID/notarization packaging for iOS. Public App Store publication and credentials require a separate release task.

## 9. Implementation Decisions To Verify Early

The product defaults above are actionable. These engineering questions must be answered with a small on-device vertical slice before broad UI work:

- External iCloud folder permission restoration after relaunch/reboot/revocation on the minimum and current supported iOS versions.
- How the selected provider exposes placeholders, hidden metadata, unavailable children and version conflicts; whether required atomic creation/replacement/move operations are supported.
- Minimum capability/Info.plist configuration for the selected open-in-place flow; creation of an empty local or iCloud folder through Files.
- Presenter/coordination queue ownership and background expiration behavior under Swift 6 concurrency.
- Availability of signing and minimum/current simulator runtimes in development/CI. Lack of physical-device access leaves interoperability explicitly unverified, not implicitly passed.

Record results in the implementation handoff. If the external-folder approach fails a required safety test, stop that milestone and propose a documented design change; do not silently replace the shared-vault model with import/export or a database.

### Apple references

- [Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories): folder selection, bookmarks and access lifetime.
- [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) and [NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter): coordination and iOS foreground/background registration.
- [Downloading ubiquitous items](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)): request materialization, then observe availability.
- [NSFileVersion](https://developer.apple.com/documentation/foundation/nsfileversion): unresolved provider-version handling.

Verify APIs and availability against the implementation SDK; the repository's file contract remains authoritative for Taskmark semantics.
