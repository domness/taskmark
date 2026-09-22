# Architecture

## Decision Summary

Taskmark is Apple-native and macOS-first. SwiftUI provides the app shell, while Swift packages hold all portable behavior. iOS will reuse those packages after the file contract and desktop workflows are reliable. A later web client must implement the same documented Markdown contract; it does not determine today's native architecture.

Markdown is canonical. Any index or cache is derived, disposable, and rebuildable.

## Targets

The macOS product is `Taskmark.app`, and the CLI executable is `taskmark`. Existing `LocalTodo*` modules and the app bundle identifier remain stable. Vault schema 2 stores metadata under `.config/`.

```text
LocalTodoApp ---> LocalTodoMarkdown <--- LocalTodoCLI
      |                   |
      +--> LocalTodoDomain <+
```

### LocalTodoDomain

Owns value types, validation, recurrence rules, view membership, and state transitions. It has no dependency on SwiftUI, Argument Parser, Yams, or concrete filesystems.

### LocalTodoMarkdown

Owns frontmatter translation, body preservation, vault discovery, path-reference updates, file coordination, conflict reporting, and atomic writes. Yams is an implementation detail behind this target.

### LocalTodoCLI

Owns command definitions, argument validation, human output, JSON output, and process exit codes. Commands call shared domain and Markdown APIs rather than editing YAML directly.

SwiftPM exposes the `taskmark` executable. Xcode's `TaskmarkCLI` tool target compiles the same CLI sources and embeds the signed executable at `Taskmark.app/Contents/Helpers/taskmark`, separate from the app's `Taskmark` executable on case-insensitive volumes. The app does not link the CLI target. Release archives validate both architecture slices and the CLI's Developer ID signature.

Settings → General registers `/usr/local/bin/taskmark` as a symlink to the bundled executable using AppleScript's `do shell script … with administrator privileges` and the native macOS authorization dialog. Registration refuses unrelated files/links, can repair links to a moved Taskmark.app, and removes only a recognized link when disabled. App updates at the registered location are reflected automatically. Translocated or mounted-volume app copies must be moved to Applications first. The app-scoped observable registration state is derived from the actual link and refreshed on Settings activation, with serialized operations and explicit errors/cancellation handling. It is available without a vault and never stored in vault preferences.

The directly distributed macOS app is no longer App Sandbox–restricted, allowing this Obsidian-style registration flow; Hardened Runtime, Developer ID signing and notarization remain enabled. The app retains security-scoped bookmark support for vault access. Both clients otherwise use normal process filesystem permissions. Installation and shell PATH are machine-local, outside the vault contract; shell profiles are not edited. The standalone CLI does not require the app process to be running.

### LocalTodoApp

Owns SwiftUI composition, macOS vault selection, security-scoped access, keyboard commands, and presentation state. The desktop shell has a navigation sidebar, task list, collapsible task/project inspector, command palette and native Settings scene. `WorkspaceModel` owns task/project drafts, autosave, conflict handling, native history and vault-session state.

Each `WorkspaceWindowRoot` owns a distinct `WorkspaceModel` and `AppPreferences` projection of its vault configuration. The app-scoped `WorkspaceWindows` coordinates open-model lifetime, the last active Settings context and all-window termination flushing. Different vault windows can use different themes; windows on the same vault refresh shared values from disk. `WorkspaceCommands` uses SwiftUI focused scene values rather than a single app-wide model. A main-actor AppKit window-delegate bridge validates close requests, supplies a per-window UndoManager, forwards SwiftUI's scene callbacks and releases vault resources after closing. Only the initial window restores the last bookmark; newly requested windows start unbound.

## Data Flow

1. The user selects a vault containing `.config/config.yml`.
2. The Markdown target discovers typed files and reports parse failures without dropping them.
3. Domain queries drive Inbox, Today, Next, Upcoming, Waiting, Someday, All Tasks, collection/tag/priority views, search and saved filters. The app applies the vault's Custom ordering after shared query evaluation when enabled.
4. User actions produce explicit mutations.
5. The Markdown target applies mutations through coordinated atomic replacement.
6. An approximately two-second app refresh loop obtains a full vault snapshot, reconciles drafts and reloads saved filters, stylesheet and configuration. Successful app mutations merge their result immediately and refresh. Incremental filesystem indexing is not implemented.

## Persistence And Presentation

- Entity Markdown, `.config/config.yml` and optional `.config/filters.md` are canonical vault data. The optional `.config/style.css` is user-authored appearance configuration; the app only reads it. `.config/` is reserved and excluded from entity scans.
- Settings, list display preferences, sidebar ordering and Custom task ordering are stored in the manifest's `preferences` mapping. Manual order uses exact paths and view keys, without machine-specific absolute paths. UserDefaults is used only for machine-local access/window information such as the recent-vault bookmark.
- Workspace-owned preference drafts autosave through revision-checked Markdown APIs. Non-overlapping top-level fields rebase; overlapping external changes remain pending until the user chooses file or local preferences. Known-field patches preserve unknown nested YAML values. Pending preference changes participate in close/switch/quit checks.
- Task rows use one full-row native `onDrag` source without a row-wide selection button. Own-process, vault-session-bound payloads assign sidebar projects/areas or append a tag. Custom ordering consumes the same payload through native List `onInsert` within the current group; source route/group/order snapshots and drop-time validation reject stale drags. Assignments use revision-checked, field-specific transitions and register Undo only after successful persistence.
- The app's stylesheet adapter maps a bounded CSS-token syntax to native colors and spacing. It does not embed a browser or replace native control semantics. See [themes](THEMES.md) and [personalization](PERSONALIZATION.md).

## Boundary Rules

- Domain code cannot import app, CLI, YAML, or filesystem concerns.
- UI and commands cannot construct frontmatter strings.
- Concrete dependencies are composed at executable entry points.
- Protocols represent volatile boundaries, not every type.
- Cross-target models live in Domain only when they express domain meaning.

## Concurrency

Use Swift 6 strict concurrency. The vault-scoped `VaultStore` actor serializes its scans and filesystem operations. The main-actor workspace owns observable UI state and drafts, reserves mutation paths, and checks vault sessions/model epochs before publishing asynchronous results. Draft generations preserve edits made while a save is in flight. Actor isolation does not serialize separate app/CLI processes or external editors; file coordination and optimistic revisions provide the filesystem boundary.

Multi-file reference changes must satisfy the all-or-nothing contract. No enabled operation is represented as a general multi-file transaction; collection path moves remain disabled until that guarantee can be met.

## Storage Safety

- Preserve the Markdown body byte-for-byte unless the user edits it.
- Preserve unknown frontmatter values through known-field mutations.
- Write a sibling temporary file, flush it, then replace the destination atomically.
- Coordinate reads and writes with platform file coordination where iCloud may be involved.
- Report conflicts and invalid references through the app, CLI JSON, and non-zero exit codes.
- Task moves coordinate both exact URLs and use an exclusive atomic rename. Project/area moves are currently disabled: sequential replacement with best-effort rollback does not meet the multi-file mutation contract. Re-enabling them requires an explicit recovery and visibility design for external Markdown readers and writers.
- Project/area deletion rejects known task, project and saved-filter references rather than cascading. This scan is not a transaction against concurrent external reference changes. App deletion captures exact bytes for session-local Undo; restoration refuses occupied paths. See [the file contract](FILE_FORMAT.md#task-copies-and-reversible-deletion).
