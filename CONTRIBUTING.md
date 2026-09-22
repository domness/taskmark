# Contributing

Thanks for helping improve Taskmark. Focused bug fixes, tests, documentation, accessibility improvements, and changes aligned with the current roadmap are welcome.

## Before You Start

- Search existing issues before opening a new report or proposal.
- Open an issue before substantial feature or file-format work so scope and compatibility can be agreed first.
- Keep changes focused; avoid combining behavior changes with unrelated refactors.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).
- Report vulnerabilities privately through [SECURITY.md](SECURITY.md), not a public issue.

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

Record the Xcode version, commands/results and any skipped checks at handoff. Distinguish hosted view tests and build success from physical gestures, VoiceOver and full-window visual acceptance. [CI_RELEASES.md](docs/CI_RELEASES.md) describes GitHub-hosted validation and protected release signing setup.

## Changes

- Start with the smallest behavior that satisfies the issue.
- Respect the package boundaries in `docs/ARCHITECTURE.md`.
- Update `docs/FILE_FORMAT.md` and fixtures before changing persisted semantics.
- Include tests for behavior changes and regressions.
- Add app behavior tests under `Apps/LocalTodoApp/Tests`; keep domain, storage, and CLI tests under `Tests/`.
- Run `make format` before `make check`.
- Keep current behavior in the user guides and implementation status in [ROADMAP.md](docs/ROADMAP.md). Keep `MEMORY.md` to current durable decisions; use Git history for chronology and avoid duplicating test counts in multiple guides.

## Pull Requests

1. Fork the repository and create a focused branch from `main`.
2. Add tests for behavior changes and regression fixes.
3. Update affected user, contract, architecture, or design documentation.
4. Run `make format` and `make check`.
5. Open a pull request that explains the problem, solution, validation, and any remaining manual checks.

Pull requests must keep Markdown canonical, preserve unknown frontmatter and bodies, and respect the target boundaries in [ARCHITECTURE.md](docs/ARCHITECTURE.md). A maintainer may ask to split unrelated work or revise a persisted-format change before review.

## Commits

Use `type(scope): subject` with an allowed scope from `AGENTS.md`. Subjects are imperative and at most 72 characters.

Examples:

```text
feat(cli): add JSON output for task queries
fix(markdown): preserve unknown frontmatter keys
docs(skill): explain dry-run behavior
```

## License

By contributing, you agree that your contributions are licensed under the repository's [MIT License](LICENSE).
