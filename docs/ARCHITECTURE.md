# Architecture

## Decision Summary

Taskmark is Apple-native and macOS-first. SwiftUI provides the app shell, while Swift packages hold all portable behavior. iOS will reuse those packages after the file contract and desktop workflows are reliable. A later web client must implement the same documented Markdown contract; it does not determine today's native architecture.

Markdown is canonical. Any index or cache is derived, disposable, and rebuildable.

## Targets

The macOS product is `Taskmark.app`. Existing `LocalTodo*` target/module names, the `localtodo` executable, bundle identifier and `.localtodo` metadata paths remain stable through the display-name change.

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

### LocalTodoApp

Owns SwiftUI composition, macOS vault selection, security-scoped access, keyboard commands, and presentation state. The desktop shell has a navigation sidebar, task list, collapsible task/project inspector, command palette and native Settings scene. `WorkspaceModel` owns task/project drafts, autosave, conflict handling, native history and vault-session state.

Each `WorkspaceWindowRoot` owns a distinct `WorkspaceModel`. The app-scoped `WorkspaceWindows` coordinates shared `AppPreferences`, open-model lifetime, the last active Settings context and all-window termination flushing. `WorkspaceCommands` uses SwiftUI focused scene values rather than a single app-wide model. A main-actor AppKit window-delegate bridge validates close requests, supplies a per-window UndoManager, forwards SwiftUI's scene callbacks and releases vault resources after closing. Only the initial window restores the last bookmark; newly requested windows start unbound.

## Data Flow

1. The user selects a vault containing `.localtodo/config.yml`.
2. The Markdown target discovers typed files and reports parse failures without dropping them.
3. Domain queries drive Inbox, Today, Next, Upcoming, Waiting, Someday, All Tasks, collection/tag/priority views, search and saved filters. The app may apply device-local Custom ordering after shared query evaluation.
4. User actions produce explicit mutations.
5. The Markdown target applies mutations through coordinated atomic replacement.
6. An approximately two-second app refresh loop obtains a full vault snapshot, reconciles drafts and reloads saved filters, stylesheet and configuration. Successful app mutations merge their result immediately and refresh. Incremental filesystem indexing is not implemented.

## Persistence And Presentation

- Entity Markdown, `.localtodo/config.yml` and optional `.localtodo/filters.md` are canonical vault data. The optional `.config/style.css` is user-authored appearance configuration; the app only reads it.
- UserDefaults holds device-local settings, list display preferences, independent sidebar ordering and Custom task ordering. Manual order uses exact paths, scoped per vault URL and route; it does not change Markdown, CLI sorting or saved-filter definitions.
- Custom task ordering uses native List moves within the current group. Transferable task drags assign sidebar collections under automatic sorts; they are omitted in Custom mode to avoid competing gestures.
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
