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
swift run taskmark init "$HOME/Taskmark" --timezone Europe/London
```

Add and query a task:

```bash
swift run taskmark add --vault "$HOME/Taskmark" \
  "Tasks/Review launch.md" --title "Review launch" --status next --priority p1
swift run taskmark list --vault "$HOME/Taskmark" --view next
```

Open `LocalTodo.xcodeproj` and run the `LocalTodoApp` scheme to build **Taskmark.app**. Create a new vault from the first-run screen, or open a vault containing `.config/config.yml`. The app stores a security-scoped bookmark so it can restore that selection on later launches.

Taskmark was previously named Local Todo. The CLI and companion skill are now named `taskmark`; the old `localtodo` command is not an alias. The bundle identifier and existing internal Swift modules remain stable. **Version 0.1.0 uses vault schema 2:** `.config/config.yml` holds timezone, theme, appearance, calendar/display preferences and all manual ordering/view options. Saved filters live in `.config/filters.md`; custom styles remain in `.config/style.css`. The earlier `.localtodo` layout is not supported, and no migration is provided for the unused development format.

Use **File → New Vault Window** (`Command-Shift-N`) to work with multiple vaults at once. Each window keeps its own selection, drafts and undo history. Preferences belong to the selected vault, so different vaults can have different themes. Copy or sync the entire vault, including `.config/`, to share its preferences between machines; external changes reload automatically.

## CLI

Choose **Taskmark → Install Command-Line Tool…** in the macOS app. Save the bundled `taskmark` executable in a writable folder on your shell's PATH, such as `~/.local/bin`; the native Save dialog supports creating folders and Go to Folder (`Shift-Command-G`). No Xcode or separate download is needed. The installer exports a standalone copy; run it again after updating the app to update the command. Canceling leaves files unchanged, and replacing an existing command uses the Save dialog's normal confirmation.

If needed, add `export PATH="$HOME/.local/bin:$PATH"` to your shell configuration (for zsh, `~/.zshrc`) and open a new terminal. Verify with `taskmark --help`. The installer does not edit shell configuration or require administrator privileges; choose a user-writable destination.

For development, run `swift build -c release` to build `.build/release/taskmark`, or use `swift run taskmark`.

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

Commands resolve the nearest ancestor vault by default. Pass `--vault PATH` to target one explicitly, `--json` for stable machine-readable output, and `--dry-run` to preview mutations. `taskmark doctor` exits with status 10 when it finds diagnostics.

**Intentional CLI behavior change:** `edit --status done` now applies recurrence using the edited rule, dates and reset preference, matching the app inspector and `complete`. To finish a recurring task permanently, use `edit --clear-recurrence --status done`. JSON entity output retains the `recurrence` mode and adds `repeat_rule` or `repeat_after` for inspecting the full rule, plus `reset_checklist_on_repeat`.

```bash
taskmark edit --vault "$HOME/Taskmark" --dry-run --json \
  "Tasks/Review launch.md" --scheduled 2026-08-01 --tag launch
taskmark move --vault "$HOME/Taskmark" --dry-run --json \
  "Tasks/Review launch.md" "Tasks/Review release.md"
taskmark doctor --vault "$HOME/Taskmark" --json
```

Entity identity is the exact, case-sensitive, vault-relative path. Prefer the CLI for task moves and the app or CLI for known-field mutations so unknown frontmatter and Markdown bodies are preserved; without them, follow the direct-file skill below. Change project/area titles without renaming their files for now; external path moves can break references. Move dry runs perform the same preflight validation without writing, but cannot reserve paths against later external changes.

## Agent Skills

- [taskmark](skills/taskmark/SKILL.md): manage vaults through the CLI, using shared validation, dry runs, and coordinated mutations.
- [taskmark-vault](skills/taskmark-vault/SKILL.md): understand and work directly with vault folders, `.config/`, Markdown, and YAML frontmatter when the CLI is unavailable or file-level work is requested. Includes task/project/area schemas, saved filters, lifecycle and recurrence rules, and conflict-aware editing guidance.

Copy the selected skill's entire directory into your agent's skills location, including `references/` when present. The file-level skill is self-contained and requires neither the Taskmark app nor a source checkout. Direct filesystem tools must still provide the publication and concurrency protections described by the skill.

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
Sources/LocalTodoCLI/      taskmark command-line interface
Tests/                     domain, storage, and CLI tests
skills/taskmark/           CLI-based agent skill
skills/taskmark-vault/     self-contained direct-file vault skill
docs/                      contracts, user guides, roadmap and CI/release setup
```

See [FILE_FORMAT.md](docs/FILE_FORMAT.md) for the canonical vault contract and [ROADMAP.md](docs/ROADMAP.md) for current status and remaining work.
