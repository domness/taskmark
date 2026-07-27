# Local Todo

Local Todo is a local-first GTD task manager whose source of truth is a directory of human-readable Markdown files. The macOS app and CLI share the same domain rules and storage implementation, so every change remains inspectable outside the app.

V1 includes inbox, Today, Next, projects, areas, tags, priorities, dates, deadlines, recurrence, search, diagnostics, atomic moves, and conflict-aware edits. iOS is next; a web client is intentionally deferred.

## Requirements

- macOS 15 or newer
- Xcode with Swift 6 support
- XcodeGen
- SwiftFormat and SwiftLint for development

## Quick Start

Set up the development checkout and initialize a vault:

```bash
make bootstrap
swift run localtodo init "$HOME/Local Todo" --timezone Europe/London
```

Add and query a task:

```bash
swift run localtodo add --vault "$HOME/Local Todo" \
  "Tasks/Review launch.md" --title "Review launch" --status next --priority p1
swift run localtodo list --vault "$HOME/Local Todo" --view next
```

Open `LocalTodo.xcodeproj`, run the `LocalTodoApp` scheme, and choose the vault. The app stores a security-scoped bookmark so it can restore that selection on later launches.

## CLI

Run `swift build -c release` to build `.build/release/localtodo`, or use `swift run localtodo` during development.

```text
init       Initialize a vault
add        Add a task
list       List and combine task filters
show       Show any entity by exact path
edit       Edit task fields or body
complete   Complete or roll forward a recurring task
reopen     Restore a completed task to an incomplete status
search     Search titles, bodies, and tags with combined filters
project    Add, list, show, edit, complete, and reopen projects
area       Add, list, show, edit, archive, and activate areas
move       Move an entity and update known path references atomically
doctor     Report malformed files and unresolved references
schema     Describe the supported schema
```

Commands resolve the nearest ancestor vault by default. Pass `--vault PATH` to target one explicitly, `--json` for stable machine-readable output, and `--dry-run` to preview mutations. `localtodo doctor` exits with status 10 when it finds diagnostics.

```bash
localtodo edit --vault "$HOME/Local Todo" --dry-run --json \
  "Tasks/Review launch.md" --scheduled 2026-08-01 --tag launch
localtodo move --vault "$HOME/Local Todo" --dry-run --json \
  "Projects/App.md" "Projects/Local Todo.md"
localtodo doctor --vault "$HOME/Local Todo" --json
```

Entity identity is the exact, case-sensitive, vault-relative path. Use the CLI or app for moves and known-field mutations so unknown frontmatter and Markdown bodies are preserved.

## Development

```bash
make format
make check
```

`make check` runs strict formatting and lint checks, Swift package and macOS app tests, and an unsigned debug app build.

## Repository Map

```text
Apps/LocalTodoApp/         macOS SwiftUI composition and app tests
Sources/LocalTodoDomain/   domain values and rules
Sources/LocalTodoMarkdown/ schema and transactional file storage
Sources/LocalTodoCLI/      localtodo command-line interface
Tests/                     domain, storage, and CLI tests
skills/local-todo/         portable agent skill
docs/                      architecture, format, and roadmap
```

See `docs/FILE_FORMAT.md` for the canonical vault contract and `docs/ROADMAP.md` for post-V1 work.
