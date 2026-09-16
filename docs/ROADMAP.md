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

## Next: iOS

- Reuse Domain and Markdown targets.
- Today-first tabs for Today, Inbox, Next, and Search; projects, areas, and tags under Browse.
- Validate iCloud Drive coordination and conflict behavior across macOS and iOS.

## Later: Web

- Implement the same versioned Markdown contract.
- Decide separately between browser folder access and an optional sync service.
- Do not imply universal iCloud Drive access from a browser.
