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

`make bootstrap` resolves Swift packages, generates `LocalTodo.xcodeproj`, and opts this clone into the repository's Git hooks. `make check` runs formatting/strict lint, release-script checks, package, macOS app, shared iOS and phone/tablet UI tests, then builds both unsigned Debug apps. The generated project is ignored; change `project.yml` and run `make generate` after pulling source additions or changing project settings.

Use the smallest suite that exercises the change while developing:

| Command | Runs |
| --- | --- |
| `make test-unit` | Swift package tests: domain rules, file behavior, workspace, presentation and CLI. No app or simulator. Use `swift test --filter <name>` for a focused case. |
| `make test-macos` | macOS app-hosted tests, including native window, toolbar and keyboard scenarios. |
| `make test-ios-unit` | Shared package and mobile app-hosted tests on the configured iPhone simulator. No UI automation or simulator clones. |
| `make test-ios-phone` | iPhone UI automation only. |
| `make test-ios-tablet` | iPad onboarding, accessibility text and adaptive navigation UI automation only. |

`make test` combines the package and macOS suites; `make test-ios` combines all three iOS suites. The phone-only commands do not require an iPad, and the tablet-only command does not require an iPhone. If your local simulators differ from the defaults, set `IOS_SIMULATOR_NAME` and/or `IOS_TABLET_SIMULATOR_ID` on the `make` command line. Run `make check` before handing off a code change.

Use `make build` for a focused unsigned macOS build and `make build-ios` for a focused unsigned simulator build. For a macOS Xcode Build/Run failure, also validate the normal signed path:

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
- Add platform-shell behavior tests under `Apps/LocalTodoApp/Tests` or `Apps/LocalTodoIOSApp/Tests` and UI automation under `Apps/LocalTodoIOSApp/UITests`. Keep portable Domain, Markdown, Workspace, Presentation and CLI tests under `Tests/`; the shared suites must remain runnable on iOS where configured.
- Test rules and file mutations in the package where possible. Use hosted tests for platform integration and real UI scenarios for behavior that needs a window or simulator, such as focus, toolbar geometry, navigation, and accessibility settings. Avoid repeating every model edge case through UI automation.
- Run `make format` before `make check`.
- Keep current behavior in the user guides and implementation status in [ROADMAP.md](docs/ROADMAP.md). Keep `MEMORY.md` to current durable decisions; use Git history for chronology and avoid duplicating test counts in multiple guides.

## Pull Requests

1. Fork the repository and create a focused branch from `main`.
2. Add tests for behavior changes and regression fixes.
3. Update affected user, contract, architecture, or design documentation.
4. For pure documentation changes, review accuracy, links and examples, and run `git diff --check`; do not run `make check`. For other changes, run `make format` and `make check`.
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
