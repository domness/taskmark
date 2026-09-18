# Taskmark

Taskmark is a local-first GTD task manager whose source of truth is a directory of human-readable Markdown files. The macOS app and CLI share the same domain rules and storage implementation, so every change remains inspectable outside the app.

The macOS app supports Inbox, Today, Next, Upcoming, Waiting and Someday; project editing and completion; interactive note checklists; editable fixed/after-completion recurrence; saved combined filters; and keyboard capture, completion and rescheduling. Task and project edits autosave with conflict handling and native undo/redo. Custom drag ordering, token-based tags, multiline title editing, task context actions and reversible project/area deletion support daily use. Settings includes calendar/display preferences, vault timezone editing and native themes with optional stylesheet overrides. Project and area path moves remain disabled pending safe multi-file recovery.

See the [daily workflow guide](docs/DAILY_WORK.md) for controls and shortcuts, [personalization](docs/PERSONALIZATION.md) for ordering and context actions, and [settings](docs/SETTINGS.md) for preferences. The [roadmap](docs/ROADMAP.md) separates implemented work from remaining validation and planned platforms.

## Requirements

- macOS 15 or newer
- Xcode with Swift 6 support
- XcodeGen
- SwiftFormat and SwiftLint for development

## Quick Start

Set up the development checkout and initialize a vault:

```bash
make bootstrap
swift run localtodo init "$HOME/Taskmark" --timezone Europe/London
```

Add and query a task:

```bash
swift run localtodo add --vault "$HOME/Taskmark" \
  "Tasks/Review launch.md" --title "Review launch" --status next --priority p1
swift run localtodo list --vault "$HOME/Taskmark" --view next
```

Open `LocalTodo.xcodeproj` and run the `LocalTodoApp` scheme to build **Taskmark.app**. Create a new vault from the first-run screen, or open a vault containing `.config/config.yml`. The app stores a security-scoped bookmark so it can restore that selection on later launches.

Taskmark was previously named Local Todo. The `localtodo` CLI command, bundle identifier and internal Swift/Xcode target names remain stable. **Version 0.1.0 uses vault schema 2:** `.config/config.yml` holds timezone, theme, appearance, calendar/display preferences and all manual ordering/view options. Saved filters live in `.config/filters.md`; custom styles remain in `.config/style.css`. The earlier `.localtodo` layout is not supported, and no migration is provided for the unused development format.

Use **File → New Vault Window** (`Command-Shift-N`) to work with multiple vaults at once. Each window keeps its own selection, drafts and undo history. Preferences belong to the selected vault, so different vaults can have different themes. Copy or sync the entire vault, including `.config/`, to share its preferences between machines; external changes reload automatically.

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
reschedule Move paired dates together while preserving their offset
search     Search titles, bodies, and tags with combined filters
filter     Save, list, run, and delete named vault filters
project    Add, list, show, edit, complete, and reopen projects
area       Add, list, show, edit, archive, and activate areas
move       Move a task atomically; project and area moves are disabled
doctor     Report malformed files and unresolved references
schema     Describe the supported schema
```

Commands resolve the nearest ancestor vault by default. Pass `--vault PATH` to target one explicitly, `--json` for stable machine-readable output, and `--dry-run` to preview mutations. `localtodo doctor` exits with status 10 when it finds diagnostics.

**Intentional CLI behavior change:** `edit --status done` now applies recurrence using the edited rule, dates and reset preference, matching the app inspector and `complete`. To finish a recurring task permanently, use `edit --clear-recurrence --status done`. JSON entity output retains the `recurrence` mode and adds `repeat_rule` or `repeat_after` for inspecting the full rule, plus `reset_checklist_on_repeat`.

```bash
localtodo edit --vault "$HOME/Taskmark" --dry-run --json \
  "Tasks/Review launch.md" --scheduled 2026-08-01 --tag launch
localtodo move --vault "$HOME/Taskmark" --dry-run --json \
  "Tasks/Review launch.md" "Tasks/Review release.md"
localtodo doctor --vault "$HOME/Taskmark" --json
```

Entity identity is the exact, case-sensitive, vault-relative path. Use the CLI for task moves and the app or CLI for known-field mutations so unknown frontmatter and Markdown bodies are preserved. Change project/area titles without renaming their files for now; external path moves can break references. Move dry runs perform the same preflight validation without writing, but cannot reserve paths against later external changes.

## Development

Main-branch CI is configured to run the full quality gate on the personal macOS runner. The release workflow packages a Developer ID–signed, notarized universal app in DMG and ZIP form after runner/signing prerequisites are met. See [Mac Mini CI and release setup](docs/CI_RELEASES.md) for configuration, validation boundaries and installation instructions.

```bash
make format
make check
```

`make check` runs strict formatting and lint checks, release-script input/syntax checks, Swift package and macOS app tests, and an unsigned debug app build.

## Repository Map

```text
Apps/LocalTodoApp/         macOS SwiftUI composition and app tests
Sources/LocalTodoDomain/   domain values and rules
Sources/LocalTodoMarkdown/ schema, revision checks and atomic file operations
Sources/LocalTodoCLI/      localtodo command-line interface
Tests/                     domain, storage, and CLI tests
skills/local-todo/         portable agent skill
docs/                      contracts, user guides, roadmap and CI/release setup
```

See [FILE_FORMAT.md](docs/FILE_FORMAT.md) for the canonical vault contract and [ROADMAP.md](docs/ROADMAP.md) for current status and remaining work.
