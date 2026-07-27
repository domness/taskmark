# Local Todo

Local Todo is a local-first GTD task manager whose source of truth is a directory of human-readable Markdown files. The macOS app and built-in CLI will share the same domain and storage implementation; iOS follows after the desktop file contract is proven, and the web client is intentionally deferred.

The project is in its foundation phase. `PRODUCT.md`, `DESIGN.md`, and the documents under `docs/` define the agreed direction. The current app and CLI are compileable scaffolds, not a usable task manager yet.

## Technology

- Swift 6 with strict concurrency
- SwiftUI, macOS 15 and newer
- Swift Package Manager for focused domain, Markdown, and CLI targets
- XcodeGen for the macOS application project
- Swift Argument Parser and Yams behind local package boundaries
- Swift Testing, SwiftFormat, and SwiftLint

## Setup

```bash
make bootstrap
make check
make run-cli
```

Open the generated `LocalTodo.xcodeproj` to run the macOS shell.

## Repository Map

```text
Apps/LocalTodoApp/         macOS SwiftUI composition
Sources/LocalTodoDomain/   domain values and rules
Sources/LocalTodoMarkdown/ schema and file storage
Sources/LocalTodoCLI/      localtodo command-line interface
Tests/                     package tests
skills/local-todo/         portable agent skill
docs/                      architecture, format, and roadmap
```

## Status

The CLI currently exposes version and schema introspection only. File mutation commands will be added after round-trip preservation and atomic-write behavior have integration tests.
