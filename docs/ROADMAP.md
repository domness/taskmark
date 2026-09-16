# Roadmap

## Foundation

- Product, design, architecture, and file-format contracts.
- Swift package and macOS app scaffolds.
- Formatting, linting, tests, CI, and Conventional Commit validation.
- Portable Local Todo agent skill.

## V1: macOS And CLI

### Run Your Day — Implemented

- App recurrence editing, interactive note checklists and opt-in reset on repeat.
- Fixed recurrence skips missed occurrences; after-completion remains completion-day anchored.
- Project title/notes/status editing, completion/reopening and inactive navigation.
- Combined/saved filters with shared CLI execution and stable sorting.
- Upcoming, Waiting and Someday with keyboard capture, completion and paired-date rescheduling.
- Automated persistence, history, failure/conflict evidence and passing quality gate: [acceptance record](RUN_YOUR_DAY.md). See [daily workflows and shortcuts](DAILY_WORK.md).

Live UI/VoiceOver checks, screenshots, a real-use pilot and iCloud validation are not claimed by this implementation milestone. Todoist migration and mobile/web work remain outside it.

### Trust The Files Follow-Up

- Restore project/area path moves only after designing and testing multi-file recovery, concurrent-writer behavior, and external-reader visibility. These moves are currently rejected before mutation; task moves use exclusive atomic rename.
- Fixed recurrence skips missed occurrences through the completion day. Inspector completion uses the shared transition, with grouped status/date undo and conflict checks for externally changed recurrence inputs.
- Validate real iCloud behavior and crash/power-loss recovery before claiming sync or durability guarantees.

### Feature Scope

- Vault selection, security-scoped persistence, indexing, and external-change observation.
- Atomic Markdown round trips that preserve bodies and unknown frontmatter.
- Inbox, Today, Next, projects, areas, tags, priorities, scheduled dates, and deadlines.
- Explicit task states: inbox, next, waiting, someday, done, and canceled.
- Search and combined filtering.
- Fixed and after-completion recurrence using the documented strict grammar.
- Markdown checklists inside task bodies.
- Desktop sidebar, task list, collapsible inspector, inline editing, and command palette.
- Full CLI operations with readable output, stable JSON, dry runs, and explicit exit codes.
- `localtodo doctor` for schema, reference, and conflict diagnostics.

Natural-language capture, reminders, collaboration, and first-class child tasks are outside V1.

## Nice To Have: macOS Polish And Personalization

Requested enhancements, with a proposed delivery order. These are planned ideas, not implemented capabilities; settle the open questions below before implementation.

### 1. Priority Highlights

- Highlight tasks using the requested mapping: **P1 red**, **P2 orange**, **P3 blue**, **P4 no custom color**. Tasks without a priority also retain the default appearance.
- Start with a restrained priority indicator in the task row; decide whether the title should also be tinted during visual review. Avoid colored side stripes, in keeping with `DESIGN.md`.
- Retain a text or icon cue and accessible priority label so color is never the only signal. Check light/dark appearance, selection, completed tasks, and increased contrast.
- Acceptance: changing priority updates the row consistently across task views without changing task order or other metadata.

### 2. Task Context Menu: Duplicate, Delete, Copy

- Add native right-click actions to task rows, with equivalent keyboard/menu access.
- **Duplicate:** create an independent task at a new, collision-safe path, preserving notes, checklists, unknown frontmatter, and relevant task metadata. Use fresh creation/update timestamps. Decide how titles, completed/canceled state, completion timestamps, and recurrence should be handled before implementation.
- **Delete:** remove the selected task with native undo and a clear recovery path. Choose Trash versus reversible deletion explicitly; account for unsaved drafts and external edits.
- **Copy:** copy task content to the clipboard. Decide whether the default is the title, a Markdown representation, or the vault-relative path; label distinct copy actions clearly if more than one is offered.
- Acceptance: actions target the right-clicked task, preserve pending edits appropriately, surface write conflicts, and register mutation undo only after persistence succeeds. Define multi-selection behavior before enabling batch actions.

### 3. Drag To Reorder Projects And Areas

- Allow manual reordering within the sidebar's Projects section and, independently, within its Areas section.
- Share the ordering interaction and persistence approach across both collection types. Provide keyboard-accessible Move Up/Move Down actions and a way to restore the default order.
- Reordering changes presentation only: it must not move or rename Markdown files, change entity identity, or assign a project to an area.
- Persist the chosen order across launches. Before implementation, decide whether order is device-local or vault-portable, document its storage, and define behavior for newly added, missing, externally moved, or archived collections.
- Acceptance: each section restores its order independently, task-to-collection drag assignment still works, and stale or cross-vault drags cannot reorder the active vault.

### 4. Vault Stylesheets In `.config/`

- Explore user-authored CSS stylesheets inside the vault's `.config/` folder to customize the native UI.
- SwiftUI has no browser CSS engine. First validate a documented, limited CSS subset mapped to native appearance tokens, such as semantic colors, typography, and spacing. Keep the Apple-native architecture; arbitrary browser selectors and layout rules are not assumed to work.
- Define the stylesheet entry point, supported selectors/properties, light/dark overrides, precedence, reload behavior, and diagnostics before committing to a format.
- Surface invalid or unsupported styles without editing the user's stylesheet; provide a way to return to the built-in appearance. Preserve keyboard focus visibility, scalable text, and non-color state cues.
- `.config/` is a requested future location, not currently a reserved directory in the vault contract. Document discovery and path rules before introducing it; keep the existing `.localtodo/config.yml` manifest role intact.
- Acceptance: a documented sample stylesheet changes supported native tokens, external edits reload predictably, and a missing or invalid stylesheet leaves the app usable.

Priority highlights and context actions offer immediate daily-use value. Project and area ordering should ship together because they share behavior. Stylesheets come last because they require a native styling adapter and a new configuration contract.

## Next: iOS

- Reuse Domain and Markdown targets.
- Today-first tabs for Today, Inbox, Next, and Search; projects, areas, and tags under Browse.
- Validate iCloud Drive coordination and conflict behavior across macOS and iOS.

## Later: Web

- Implement the same versioned Markdown contract.
- Decide separately between browser folder access and an optional sync service.
- Do not imply universal iCloud Drive access from a browser.
