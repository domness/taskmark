# Roadmap

Status reviewed against the repository on 2026-09-22. Implemented features below are backed by source and automated checks; they do not imply completed manual acceptance.

## Implemented: macOS And CLI

### Local-First Foundation

- Swift 6 Domain and Markdown targets shared by the native macOS app and CLI, with documented [architecture](ARCHITECTURE.md) and [vault contract](FILE_FORMAT.md).
- Vault schema 2 uses `.config/` for the manifest, saved filters, stylesheet and shared preferences. The unused earlier development format has no migration or fallback, as requested.
- Safe empty-folder initialization, vault selection and security-scoped restoration, full-scan snapshots and periodic external-change refresh.
- Revision-checked atomic updates, preservation of unknown frontmatter and Markdown bodies, visible malformed-file and missing-reference diagnostics.
- Workspace-owned task/project autosave, non-overlapping rebases, explicit conflict resolution, task-file recovery and native Undo/Redo.
- Independent vault windows through File → New Vault Window, focused-window commands and per-window Undo/Redo. Closing flushes the affected workspace; quitting checks all open workspaces. Full multi-vault session restoration remains outside the implemented behavior.
- `taskmark` CLI entity/query/lifecycle commands, task moves, JSON output, mutation dry runs and `doctor`; portable CLI-first and direct-file agent skills. Settings → General → Command-line interface automatically registers the bundled CLI at `/usr/local/bin/taskmark` with native administrator authorization. Registration follows updates at the same app location and can be disabled from Settings.

### Daily Workflows

- Inbox, Today, Next, Upcoming, Waiting, Someday and All Tasks, plus project/area/tag/priority views and search. Inbox precedes Today in the sidebar.
- Contextual capture, keyboard selection/editing/completion and paired-date rescheduling.
- Fixed and after-completion recurrence; late fixed completion skips missed occurrences. Interactive body checklists and opt-in checklist reset on repeat.
- Project title/notes/status editing, completion/reopening and collapsed inactive-project navigation.
- Combined filters and canonical saved filters shared with the CLI, with explicit Save/Update and conflict recovery.
- Automatic sorting and **Custom** drag ordering per view/vault, persisted in shared configuration. Grouped custom moves stay within their group; hidden task positions and order across launches/sort switches are retained.

See [daily workflows and shortcuts](DAILY_WORK.md).

### Task Editing And Personalization

- The focused canvas opens with two columns. A row click selects and opens the optional notes-first inspector without entering edit mode; the toolbar toggles it and Command-E focuses the title. Backspace deletes from the list, while inspector text editing retains normal Backspace behavior.
- Incomplete tasks past their scheduled date or deadline are highlighted with semantic red and an Overdue label, using the vault-local day.
- Placeholder-only, multiline title entry; always-visible project, area, tag and repeat controls. Tags are removable tokens with an add button and existing-tag suggestions.
- Composed task inspector with a title-side completion control, Planning/Organization property groups, borderless aligned values and collapsed file details. Save problems and recovery remain visible independently of file details.
- Rendered-first Markdown task and project titles and notes, with click-to-edit source and return to rendering on focus loss; includes inspector links, headings, lists, quotes and code. Source text remains canonical.
- Task rows resize as planning metadata appears or disappears. Search/list headers stay top-aligned; Switch Vault has its own footer; the inspector toggle is at the trailing window toolbar.
- Task Duplicate/Delete/Copy actions; project/area/tag context-menu removal with automatic assignment cleanup, including completed tasks and saved filters. Session-local Undo/Redo restores deleted collection bytes and affected assignments; interrupted cleanup reports reversible partial progress.
- Independent native Projects/Areas sidebar ordering, with Move Up/Move Down/Restore Default Order actions.
- Drag unselected tasks directly from the full row onto sidebar projects, areas or tags, with additive tag assignment and field-specific Undo/Redo. Custom order uses the same row drag for native list insertion.
- P1 red/P2 orange/P3 blue indicators and labels, neutral task titles and optional native CSS-token overrides in `.config/style.css`.

See [personalization](PERSONALIZATION.md).

### Settings And Themes

- Opt-in Settings → General → Dock → Badge matches the unfiltered Today count in the most recently active vault, with zero hidden and the preference shared through the vault.

- Resizable native Settings with a fixed General/Theme sidebar and compact titlebar.
- Persistent week start, date/time display, startup view, appearance, palette and stylesheet preferences.
- All vault preferences, including sidebar/custom order and per-view display options, travel with `.config/config.yml`. External changes reload; same-field conflicts require explicit resolution. Bookmarks and window geometry remain machine-local.
- Canonical active-vault timezone editing shared with CLI date semantics.
- System/Light/Dark appearance and Taskmark, Slate, Forest, Sand, Catppuccin (Latte/Mocha) and Dracula (Alucard/Dracula) palettes, with custom-style diagnostics and reload.
- Bundled Inter typography for Dracula and Figtree for Catppuccin, with a slightly larger 14-point interface default for Catppuccin and window-wide stylesheet size overrides.

See [settings](SETTINGS.md) and [themes](THEMES.md).

### Build And Distribution Tooling

- `make check` regenerates the project, checks formatting/lint and release scripts, runs package/macOS app tests, and builds the unsigned Debug app.
- All quality and release jobs target GitHub-hosted runners. The release workflow validates a merged commit without credentials, gates signing through the owner-approved `release` environment and grants release-write permission only to the upload job.
- Release scripts build a universal macOS app, select the pinned Developer ID identity and explicit temporary notarization Keychain, notarize/staple, and upload DMG/ZIP/checksum assets to an existing published release. The former personal-runner pipeline published through 0.8.1; the hosted credential path still requires an approved release validation. Downloaded-app interaction remains a separate manual acceptance step.

See [CI and release setup](CI_RELEASES.md).

## Remaining macOS Validation And Storage Work

- Exercise complete native windows, small-window layouts, physical drag gestures, keyboard/VoiceOver traversal and light/dark/Increase Contrast appearance. Hosted tests already cover dynamic row height and Backspace routing between the inspector and list; those checks are narrower than full UI acceptance.
- Run a real-use pilot and validate iCloud behavior, concurrent external editors and crash/power-loss recovery before claiming synchronization or durability guarantees.
- Restore project/area path moves only after a multi-file recovery and visibility design satisfies the atomic reference-update contract. They remain rejected before mutation; task moves use exclusive atomic rename.
- Continue downloaded-app launch and interaction acceptance for each release; successful signing/notarization does not establish full UI correctness.

The maintained test suites under `Tests/` and `Apps/LocalTodoApp/Tests/` are the automated evidence; use the current `make check` result rather than historical test counts.

## Next Platform: iOS — Planned

- Reuse Domain and Markdown targets after desktop reliability and storage validation.
- Proposed Today/Inbox/Next/Search navigation, with collections under Browse; final mobile navigation remains to be designed.
- Validate iCloud Drive coordination and conflict behavior across macOS and iOS.

## Later: Web — Planned

- Implement the same versioned Markdown contract.
- Decide between browser folder access and an optional sync service; do not imply universal iCloud Drive access from a browser.

## Outside Current Scope

Natural-language capture, reminders, collaboration, first-class child-task entities and Todoist migration are not implemented or committed V1 work. Checklists remain inside parent-task Markdown bodies.
