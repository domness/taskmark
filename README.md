<p align="center">
  <img src="Apps/LocalTodoApp/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="160" height="160" alt="Taskmark app icon">
</p>

<h1 align="center">Taskmark</h1>

<p align="center">
  A native, local-first task manager for Apple platforms, backed by plain Markdown.
</p>

<p align="center">
  <a href="https://github.com/domness/taskmark/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/domness/taskmark?style=flat-square"></a>
  <a href="https://github.com/domness/taskmark/actions/workflows/quality.yml"><img alt="Quality" src="https://img.shields.io/github/actions/workflow/status/domness/taskmark/quality.yml?branch=main&style=flat-square&label=quality"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"></a>
  <img alt="macOS 15 or newer" src="https://img.shields.io/badge/macOS-15%2B-black?style=flat-square">
</p>

<p align="center">
  <img src="docs/design-exploration/native/focused-canvas.png" width="900" alt="Taskmark Today view on macOS">
</p>

Taskmark combines focused native apps for macOS, iPhone and iPad, a scriptable macOS CLI, and a transparent file format. Tasks, projects, and areas remain readable and editable without Taskmark. All clients share validation, recurrence, query, and storage foundations; the native apps also reuse portable workspace and presentation components.

## Download

Download the latest signed and notarized universal build from [GitHub Releases](https://github.com/domness/taskmark/releases/latest). Taskmark requires macOS 15 or newer and supports Apple Silicon and Intel Macs.

The iPhone/iPad app requires iOS/iPadOS 18 or newer and is currently an implementation candidate built from source. It is not yet distributed as released mobile or iCloud-sync support; the remaining physical-device and distribution gates are tracked in [iOS Acceptance Evidence](docs/IOS_ACCEPTANCE.md).

1. Open the DMG, or extract the ZIP.
2. Move **Taskmark.app** to **Applications**.
3. Open Taskmark and create an empty vault or select an existing Taskmark vault.

Release downloads include SHA-256 checksums. Taskmark does not provide a sync service; use your preferred file synchronization tool and include the vault's hidden `.config/` directory.

## Highlights

- Fast Inbox, Today, Next, Upcoming, Waiting, Someday, search, and saved-filter workflows.
- Fixed and after-completion recurrence, paired-date rescheduling, and interactive Markdown checklists.
- Projects, areas, tags, priorities, custom task ordering, and multiple independent vault windows.
- Native iPhone navigation and adaptive iPad sidebar/list/detail workflows over the same schema-2 vault.
- Rendered Markdown titles and notes with source editing when needed.
- Autosave, native Undo/Redo, device-local draft recovery, external-change refresh, conflict handling, provider availability, and malformed-file diagnostics.
- Six adaptive native themes, bundled typography, and optional per-vault style tokens.
- A bundled `taskmark` CLI with human-readable and stable JSON output.
- No canonical database, account, analytics service, or cloud dependency.

See [Daily Workflows](docs/DAILY_WORK.md) for app controls and shortcuts, and [Personalization](docs/PERSONALIZATION.md) for ordering, themes, and task actions.

## Markdown Vaults

A vault is any directory with a schema 2 manifest:

```text
My Tasks/
  .config/
    config.yml       required vault manifest and shared preferences
    filters.md       optional saved filters
    style.css        optional native appearance overrides
  Tasks/
    Review launch.md
  Projects/
    Taskmark.md
  Areas/
    Work.md
```

Each entity is a Markdown file with YAML frontmatter. Exact, case-sensitive, vault-relative paths are entity identity; Taskmark does not add hidden UUIDs. Unknown frontmatter and Markdown bodies are preserved during known-field edits.

The [File Format](docs/FILE_FORMAT.md) is the canonical contract. Taskmark was previously named Local Todo, but there is no `localtodo` command or compatibility alias. The earlier development-only `.localtodo` layout is unsupported and has no migration.

## Command Line

Move Taskmark to Applications, then enable **Taskmark → Settings → General → Command-line interface**. After approving the native administrator prompt, open a new terminal:

```bash
taskmark --help
taskmark list --vault "$HOME/Taskmark" --view today
taskmark add --vault "$HOME/Taskmark" \
  "Tasks/Review launch.md" --title "Review launch" --status next --priority p1
taskmark doctor --vault "$HOME/Taskmark" --json
```

Taskmark registers `/usr/local/bin/taskmark` as a symlink to the bundled CLI. It does not edit shell profiles, replace unrelated files, or require the app to remain open. Commands resolve the nearest ancestor vault by default; use `--vault PATH` explicitly when needed, `--json` for automation, and `--dry-run` to preview mutations.

The CLI supports vault initialization; task add/show/edit/complete/reopen/reschedule/move; combined list/search queries; saved filters; project and area lifecycle commands; schema inspection; and diagnostics. Project and area path moves remain disabled until multi-file reference updates can satisfy the documented recovery contract.

## Agent Skills

- [taskmark](skills/taskmark/SKILL.md) manages vaults through the CLI with validation and dry runs.
- [taskmark-vault](skills/taskmark-vault/SKILL.md) documents safe direct-file work when the CLI is unavailable.
- [taskmark-release](skills/taskmark-release/SKILL.md) documents the repository's signed release process.

Install a skill by copying its complete directory, including any `references/` folder, into the agent's skills location.

## Documentation

| Guide | Purpose |
| --- | --- |
| [Privacy Policy](PRIVACY.md) | Data handling, optional services, retention and privacy contact |
| [Daily Workflows](docs/DAILY_WORK.md) | macOS app behavior and keyboard shortcuts |
| [Settings](docs/SETTINGS.md) | Shared vault preferences and macOS-only settings |
| [Themes](docs/THEMES.md) | Built-in palettes and style tokens |
| [File Format](docs/FILE_FORMAT.md) | Canonical vault and entity contract |
| [Architecture](docs/ARCHITECTURE.md) | Targets, dependency direction, and storage safety |
| [Roadmap](docs/ROADMAP.md) | Implemented work, validation gaps, and later platforms |
| [iOS Specification](docs/IOS_SPEC.md) | Normative iPhone/iPad behavior, shared vaults, themes, and acceptance |
| [iOS Implementation](docs/IOS_IMPLEMENTATION.md) | Implemented work packets, dependencies, and remaining completion requirements |
| [iOS Acceptance](docs/IOS_ACCEPTANCE.md) | Verified simulator/device evidence and outstanding release blockers |
| [CI and Releases](docs/CI_RELEASES.md) | Validation, signing, notarization, and packaging |

## Build From Source

Development requires Xcode with Swift 6 support, XcodeGen, SwiftFormat, SwiftLint, and Python 3.

```bash
git clone https://github.com/domness/taskmark.git
cd taskmark
make bootstrap
make check
open LocalTodo.xcodeproj
```

Run the `LocalTodoApp` scheme to build **Taskmark.app** or `LocalTodoIOSApp` for the iPhone/iPad app. The internal `LocalTodo*` module names remain stable; both native apps use `com.tinycorestudios.taskmark`. `make check` regenerates the project, checks formatting and lint, validates release scripts, runs package, macOS, shared iOS, phone and tablet tests, and builds both Debug apps. Use `make build` or `make build-ios` for a focused unsigned build.

## Contributing

Bug reports, focused feature proposals, documentation improvements, and code contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Report security issues privately as described in [SECURITY.md](SECURITY.md).

## License

Taskmark is available under the [MIT License](LICENSE). Third-party palette and font notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The Taskmark name and app icon identify this project; the MIT license does not grant trademark rights.
