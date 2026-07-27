# Contributing

## Setup

Requirements:

- Xcode with Swift 6 support
- XcodeGen
- SwiftFormat
- SwiftLint

Run:

```bash
make bootstrap
make check
```

`make bootstrap` resolves Swift packages, generates `LocalTodo.xcodeproj`, and opts this clone into the repository's Git hooks.

## Changes

- Start with the smallest behavior that satisfies the issue.
- Respect the package boundaries in `docs/ARCHITECTURE.md`.
- Update `docs/FILE_FORMAT.md` and fixtures before changing persisted semantics.
- Include tests for behavior changes and regressions.
- Run `make format` before `make check`.

## Commits

Use `type(scope): subject` with an allowed scope from `AGENTS.md`. Subjects are imperative and at most 72 characters.

Examples:

```text
feat(cli): add JSON output for task queries
fix(markdown): preserve unknown frontmatter keys
docs(skill): explain dry-run behavior
```
