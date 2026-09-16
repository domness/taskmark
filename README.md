# Local Todo

Local Todo is a local-first GTD task manager whose source of truth is a directory of human-readable Markdown files. The macOS app and CLI share the same domain rules and storage implementation, so every change remains inspectable outside the app.

The current implementation includes inbox, Today, Next, projects, areas, tags, priorities, dates, deadlines, recurrence, search, diagnostics, atomic task moves, and conflict-aware edits. Project and area path moves are temporarily disabled pending safe multi-file recovery. iOS is planned; a web client is intentionally deferred.

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

Open `LocalTodo.xcodeproj` and run the `LocalTodoApp` scheme. Create a new vault from the first-run screen, or open an existing vault containing `.localtodo/config.yml`. The app stores a security-scoped bookmark so it can restore that selection on later launches.

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
move       Move a task atomically; project and area moves are disabled
doctor     Report malformed files and unresolved references
schema     Describe the supported schema
```

Commands resolve the nearest ancestor vault by default. Pass `--vault PATH` to target one explicitly, `--json` for stable machine-readable output, and `--dry-run` to preview mutations. `localtodo doctor` exits with status 10 when it finds diagnostics.

```bash
localtodo edit --vault "$HOME/Local Todo" --dry-run --json \
  "Tasks/Review launch.md" --scheduled 2026-08-01 --tag launch
localtodo move --vault "$HOME/Local Todo" --dry-run --json \
  "Tasks/Review launch.md" "Tasks/Review release.md"
localtodo doctor --vault "$HOME/Local Todo" --json
```

Entity identity is the exact, case-sensitive, vault-relative path. Use the CLI for task moves and the app or CLI for known-field mutations so unknown frontmatter and Markdown bodies are preserved. Change project/area titles without renaming their files for now; external path moves can break references. Move dry runs perform the same preflight validation without writing, but cannot reserve paths against later external changes.

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
