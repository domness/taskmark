# Architecture

## Decision Summary

Taskmark is Apple-native and macOS-first. Separate macOS and iOS SwiftUI shells reuse Swift packages for portable behavior. The iOS client is an implementation candidate until the required physical-device interoperability and release-readiness checks pass. A later web client must implement the same documented Markdown contract; it does not determine today's native architecture.

Markdown is canonical. Any index or cache is derived, disposable, and rebuildable.

## Targets

The products are `Taskmark.app` for macOS, Taskmark for iOS/iPadOS, and the macOS `taskmark` CLI. Existing `LocalTodo*` modules remain stable. Both native apps use the bundle identifier `com.tinycorestudios.taskmark`. Vault schema 2 stores metadata under `.config/`.

```text
LocalTodoApp --------+                    +-------- LocalTodoIOSApp
                     |                    |
                     +--> LocalTodoWorkspace <---+
                     |           |
                     |           v
                     +--> LocalTodoMarkdown <-------- LocalTodoCLI
                     |           |
                     |           v
                     +----> LocalTodoDomain <---------+

LocalTodoApp ------> LocalTodoPresentation <------ LocalTodoIOSApp
```

Both app shells also import the narrow Domain and Markdown APIs they compose. `LocalTodoCLI` imports Domain and Markdown only. Dependency arrows continue to point inward; no shared target imports a platform shell.

### LocalTodoDomain

Owns value types, validation, recurrence rules, view membership, and state transitions. It has no dependency on SwiftUI, Argument Parser, Yams, or concrete filesystems.

### LocalTodoMarkdown

Owns frontmatter translation, body preservation, vault discovery, path-reference updates, file coordination, conflict reporting, and atomic writes. Yams is an implementation detail behind this target.

### LocalTodoWorkspace

Owns portable routes, recurrence editor values, vault-session snapshots and mutations, filters, view preferences, persisted-action history, and device-local recovery checkpoint values/stores. It depends on Domain and Markdown, and imports no SwiftUI, UIKit or AppKit. The macOS shell currently consumes shared route/recurrence types while retaining `WorkspaceModel` for desktop draft/autosave orchestration; the iOS shell composes `WorkspaceSession` and the checkpoint stores. Platform shells choose checkpoint locations and trigger persistence from their OS lifecycle.

### LocalTodoPresentation

Owns shared SwiftUI palette, stylesheet parsing and presentation values without depending on either platform shell, Workspace or Markdown. Each app projects those values into its own native composition.

### LocalTodoCLI

Owns command definitions, argument validation, human output, JSON output, and process exit codes. Commands call shared domain and Markdown APIs rather than editing YAML directly.

SwiftPM exposes the `taskmark` executable. Xcode's `TaskmarkCLI` tool target compiles the same CLI sources and embeds the signed executable at `Taskmark.app/Contents/Helpers/taskmark`, separate from the app's `Taskmark` executable on case-insensitive volumes. The app does not link the CLI target. Release archives validate both architecture slices and the CLI's Developer ID signature.

Settings → General registers `/usr/local/bin/taskmark` as a symlink to the bundled executable using AppleScript's `do shell script … with administrator privileges` and the native macOS authorization dialog. Registration refuses unrelated files/links, can repair links to a moved Taskmark.app, and removes only a recognized link when disabled. App updates at the registered location are reflected automatically. Translocated or mounted-volume app copies must be moved to Applications first. The app-scoped observable registration state is derived from the actual link and refreshed on Settings activation, with serialized operations and explicit errors/cancellation handling. It is available without a vault and never stored in vault preferences.

The directly distributed macOS app is no longer App Sandbox–restricted, allowing this Obsidian-style registration flow; Hardened Runtime, Developer ID signing and notarization remain enabled. The macOS app retains security-scoped bookmark support for vault access. The iOS app uses the document picker and iOS bookmark/access lifetime for a selected folder. Installation and shell PATH are machine-local, outside the vault contract; shell profiles are not edited. The standalone CLI does not require either app process to be running.

### LocalTodoApp

Owns SwiftUI composition, macOS vault selection, security-scoped access, keyboard commands, and presentation state. The desktop shell has a navigation sidebar, task list, collapsible task/project inspector, command palette and native Settings scene. `WorkspaceModel` owns task/project drafts, autosave, conflict handling, native history and vault-session state.

The app alone links the pinned Sparkle framework. An app-scoped `AppUpdates` owns its standard updater controller and projects KVO state into the menu and Updates settings. Sparkle owns GitHub-hosted appcast/download requests, signature verification, installation, relaunch and machine-local preferences. Checking is opt-in; system profiling and automatic downloading default off. Relaunch uses normal application termination, retaining the all-window save/quit boundary. Release packaging exports the archive to sign nested Sparkle tools, then creates an EdDSA-signed ZIP enclosure in `appcast.xml` using the matching Sparkle tools. Domain, Markdown and CLI have no updater dependency.

Each `WorkspaceWindowRoot` owns a distinct `WorkspaceModel` and `AppPreferences` projection of its vault configuration. The app-scoped `WorkspaceWindows` coordinates open-model lifetime, the last active Settings context and all-window termination flushing. Different vault windows can use different themes; windows on the same vault refresh shared values from disk. `WorkspaceCommands` uses SwiftUI focused scene values rather than a single app-wide model. A main-actor AppKit window-delegate bridge validates close requests, supplies a per-window UndoManager, forwards SwiftUI's scene callbacks and releases vault resources after closing. Only the initial window restores the last bookmark; newly requested windows start unbound.

### LocalTodoIOSApp

Owns the iPhone/iPad SwiftUI composition, folder picker, security-scoped bookmark lifetime, scene lifecycle, provider observation and device-local recovery stores. It targets iOS/iPadOS 18+ and opens the same schema-2 folder in place. Foreground sessions combine `NSFilePresenter` notifications with a coalesced approximately two-second refresh loop; scans request materialization for iCloud placeholders and surface partial availability instead of treating it as a complete empty vault. Backgrounding removes the presenter and stops polling.

Mobile adds no canonical database or synchronization transport. The [iOS specification](IOS_SPEC.md) remains the normative behavior and acceptance contract, while [iOS acceptance](IOS_ACCEPTANCE.md) records current evidence and gaps. The implementation remains a candidate rather than released mobile support until the required physical iCloud, recovery, accessibility and distribution checks pass.

## Data Flow

`WorkspaceWindows` observes the Settings vault context, its badge preference, and its snapshot to publish the single app Dock badge through an app-composed AppKit closure. The count reuses the Domain Today query with the workspace's injected clock and vault time zone; it is independent of the visible route. The existing periodic snapshot refresh reevaluates calendar-day changes. Observation survives individual window closure and clears the badge when no bound workspace remains.

1. The user selects a vault containing `.config/config.yml`.
2. The Markdown target discovers typed files and reports parse failures without dropping them.
3. Domain queries drive Inbox, Today, Next, Upcoming, Waiting, Someday, Completed, All Tasks, collection/tag/priority views, search and saved filters. Completed includes `done` tasks and native clients group them by the vault-local `completed_at` day. The app applies the vault's Custom ordering after shared query evaluation when enabled.
4. User actions produce explicit mutations.
5. The Markdown target applies mutations through coordinated atomic replacement.
6. An approximately two-second active-workspace refresh loop obtains a full vault snapshot, reconciles drafts and reloads saved filters, stylesheet and configuration. iOS additionally coalesces file-presenter callbacks and materialization requests. Successful app mutations merge their result immediately and refresh. Incremental filesystem indexing is not implemented.

## Persistence And Presentation

- Entity Markdown, `.config/config.yml` and optional `.config/filters.md` are canonical vault data. The optional `.config/style.css` is user-authored appearance configuration; the app only reads it. `.config/` is reserved and excluded from entity scans.
- Settings, list display preferences, sidebar ordering and Custom task ordering are stored in the manifest's `preferences` mapping. Manual order uses exact paths and view keys, without machine-specific absolute paths. Device-local storage is limited to machine access/window information and recoverable uncommitted mobile checkpoints; it is never canonical vault state.
- Workspace-owned preference drafts autosave through revision-checked Markdown APIs. Non-overlapping top-level fields rebase; overlapping external changes remain pending until the user chooses file or local preferences. Known-field patches preserve unknown nested YAML values. Pending preference changes participate in close/switch/quit checks.
- Task rows use one full-row native `onDrag` source without a row-wide selection button. Own-process, vault-session-bound payloads move tasks to Focus destinations, assign sidebar projects/areas or append a tag. Today and Upcoming apply their contextual planning dates; Completed uses the shared completion/recurrence transition. Custom ordering consumes the same payload through native List `onInsert` within the current group; source route/group/order snapshots and drop-time validation reject stale drags. Assignments use revision-checked, field-specific transitions and register Undo only after successful persistence.
- The app's stylesheet adapter maps a bounded CSS-token syntax to native colors and spacing. It does not embed a browser or replace native control semantics. See [themes](THEMES.md) and [personalization](PERSONALIZATION.md).

## Boundary Rules

- Domain code cannot import app, CLI, YAML, or filesystem concerns.
- UI and commands cannot construct frontmatter strings.
- Concrete dependencies are composed at executable entry points.
- Protocols represent volatile boundaries, not every type.
- Cross-target business models live in Domain; portable app-session models live in Workspace; shared visual values live in Presentation.

## Concurrency

Use Swift 6 strict concurrency. The vault-scoped `VaultStore` actor serializes its scans and filesystem operations. Main-actor `WorkspaceSession` and platform workspace state own observable snapshots and drafts, reserve mutation paths, and check vault sessions/model epochs before publishing asynchronous results. Draft generations preserve edits made while a save is in flight. Actor isolation does not serialize separate apps, CLI processes or external editors; file coordination and optimistic revisions provide the filesystem boundary.

Path moves and their reference changes must satisfy the all-or-nothing contract; collection path moves remain disabled until that guarantee can be met. Organization removal is a separate, explicitly resumable cleanup workflow, not a general multi-file transaction. The Markdown actor plans the edits and returns both completed results and recovery steps when execution stops. The workspace flushes drafts, prevents overlapping app writes/refresh publication during execution, merges completed results, and registers one session-local history action. See the file contract for intermediate visibility and crash behavior.

## Storage Safety

- Preserve the Markdown body byte-for-byte unless the user edits it.
- Preserve unknown frontmatter values through known-field mutations.
- Write a sibling temporary file, flush it, then replace the destination atomically.
- Coordinate reads and writes with platform file coordination where iCloud may be involved.
- Report conflicts and invalid references through the app, CLI JSON, and non-zero exit codes.
- Task moves coordinate both exact URLs and use an exclusive atomic rename. Project/area moves are currently disabled: sequential replacement with best-effort rollback does not meet the multi-file mutation contract. Re-enabling them requires an explicit recovery and visibility design for external Markdown readers and writers.
- App project/area removal clears known task, project and saved-filter assignments before revision-checked deletion; tag removal clears the exact tag across entities and filter criteria. Per-file cleanup is conflict-checked and recoverable, with explicit partial-progress errors rather than rollback. Low-level deletion still rejects remaining references. App history captures exact deleted collection bytes and field-specific reference patches; restoration refuses occupied paths. See [the file contract](FILE_FORMAT.md#task-copies-and-reversible-deletion).
