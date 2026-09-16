# Architecture

## Decision Summary

Local Todo is Apple-native and macOS-first. SwiftUI provides the app shell, while Swift packages hold all portable behavior. iOS will reuse those packages after the file contract and desktop workflows are reliable. A later web client must implement the same documented Markdown contract; it does not determine today's native architecture.

Markdown is canonical. Any index or cache is derived, disposable, and rebuildable.

## Targets

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

Owns SwiftUI composition, macOS document selection, security-scoped access, keyboard commands, and presentation state. The planned desktop shell is a navigation sidebar, task list, and collapsible inspector.

## Data Flow

1. The user selects a vault containing `.localtodo/config.yml`.
2. The Markdown target discovers typed files and reports parse failures without dropping them.
3. Domain values drive Today, Inbox, Next, project, area, tag, and priority views.
4. User actions produce explicit mutations.
5. The Markdown target applies mutations through coordinated atomic replacement.
6. Filesystem changes invalidate and rebuild only affected derived state.

## Boundary Rules

- Domain code cannot import app, CLI, YAML, or filesystem concerns.
- UI and commands cannot construct frontmatter strings.
- Concrete dependencies are composed at executable entry points.
- Protocols represent volatile boundaries, not every type.
- Cross-target models live in Domain only when they express domain meaning.

## Concurrency

Use Swift 6 strict concurrency. A vault-scoped actor will serialize indexing and mutations. Parsing may run concurrently on immutable file snapshots, but writes to related paths and references must commit as one coordinated operation or fail without partial changes.

## Storage Safety

- Preserve the Markdown body byte-for-byte unless the user edits it.
- Preserve unknown frontmatter values through known-field mutations.
- Write a sibling temporary file, flush it, then replace the destination atomically.
- Coordinate reads and writes with platform file coordination where iCloud may be involved.
- Report conflicts and invalid references through the app, CLI JSON, and non-zero exit codes.
- Task moves coordinate both exact URLs and use an exclusive atomic rename. Project/area moves are currently disabled: sequential replacement with best-effort rollback does not meet the multi-file mutation contract. Re-enabling them requires an explicit recovery and visibility design for external Markdown readers and writers.
