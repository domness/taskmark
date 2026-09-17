# Contributing

## Setup

Requirements:

- Xcode with Swift 6 support
- XcodeGen
- SwiftFormat
- SwiftLint
- Python 3 for release-script checks

Run:

```bash
make bootstrap
make check
```

`make bootstrap` resolves Swift packages, generates `LocalTodo.xcodeproj`, and opts this clone into the repository's Git hooks. `make check` runs formatting/strict lint, release-script checks, package and macOS app tests, and an unsigned Debug app build. The generated project is ignored; change `project.yml` and run `make generate` after pulling source additions or changing project settings.

Use `make build` for a focused unsigned app build. Package-only `swift build` or `swift test` does not compile the app. For an Xcode Build/Run failure, also validate the normal signed path:

```bash
make generate
xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug -destination 'platform=macOS' clean build
```

Record the Xcode version, commands/results and any skipped checks at handoff. Distinguish hosted view tests and build success from physical gestures, VoiceOver and full-window visual acceptance. [CI_RELEASES.md](docs/CI_RELEASES.md) describes hosted/self-hosted validation and signing setup.

## Changes

- Start with the smallest behavior that satisfies the issue.
- Respect the package boundaries in `docs/ARCHITECTURE.md`.
- Update `docs/FILE_FORMAT.md` and fixtures before changing persisted semantics.
- Include tests for behavior changes and regressions.
- Add app behavior tests under `Apps/LocalTodoApp/Tests`; keep domain, storage, and CLI tests under `Tests/`.
- Run `make format` before `make check`.
- Keep current behavior in the user guides and implementation status in [ROADMAP.md](docs/ROADMAP.md). Preserve historical decisions in `MEMORY.md`; avoid duplicating test counts in multiple guides.

## Commits

Use `type(scope): subject` with an allowed scope from `AGENTS.md`. Subjects are imperative and at most 72 characters.

Examples:

```text
feat(cli): add JSON output for task queries
fix(markdown): preserve unknown frontmatter keys
docs(skill): explain dry-run behavior
```
