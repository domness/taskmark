# Agent Guidance

## Start Here

At the start of every session, read these files after this guide and before making changes or recommendations:

1. `MEMORY.md` for project decisions and prior session summaries.
2. `ERRORS.md` for approaches that previously required repeated attempts.
3. `PRODUCT.md` for users, purpose, and product principles.
4. `DESIGN.md` for visual and interaction direction.
5. `docs/FILE_FORMAT.md` before reading or writing vault files.
6. `docs/ARCHITECTURE.md` before changing target boundaries.
7. `docs/ROADMAP.md` before expanding scope.

## Repository Skills

When asked to create or publish a Taskmark release, read and follow `skills/taskmark-release/SKILL.md`. It covers version selection, validation, GitHub publication and verification of signed/notarized downloads. Agents without automatic skill discovery should read that file directly.

## Session Memory And Error Logs

Keep `MEMORY.md` as a concise summary of current, durable project decisions. Update the relevant summary when a decision changes instead of appending a chronology. Canonical product, architecture, file-format, and design details belong in their dedicated documents; do not duplicate implementation history, personal data, release credentials, or conversation details in memory.

Never contradict a current decision in `MEMORY.md` without flagging the conflict first and explaining why it may no longer apply.

When the user says "session end", "wrapping up", or "let's stop here", replace the short **Current Work** section in `MEMORY.md` with only active unfinished work and next priorities. Remove it when no handoff is needed.

Keep `ERRORS.md` as a compact set of reusable lessons for approaches that took more than 2 attempts. Merge related incidents into an existing lesson, omit one-off chronology and identifying environment details, and record only:

- Failure pattern
- Reliable approach
- Next-time rule

Check `ERRORS.md` before suggesting approaches to similar tasks.

## Permanent Project Facts

These facts are always true for this project. Apply them to every session without exception. If a task conflicts with one of these facts, flag the conflict before proceeding.

- This is Taskmark (formerly Local Todo), an Apple-native, macOS-first, local-first task manager for macOS, iPhone and iPad, with a macOS-bundled CLI, built with Swift 6. The iOS/iPadOS app is an implementation candidate rather than released mobile support until its documented acceptance gates pass. The CLI command and companion skill are named `taskmark`, with no `localtodo` alias; existing internal Swift modules remain stable, and both native apps use the bundle identifier `com.tinycorestudios.taskmark`. Vault schema 2 uses `.config/` for all metadata and shared preferences; the earlier development layout has no migration, as explicitly requested by the user.
- Follow the repository as it exists today. Do not invent missing layers, directories, or tooling because older docs, templates, or examples imply they should exist.
- `AGENTS.md`, `MEMORY.md`, `ERRORS.md`, `docs/ARCHITECTURE.md`, and `docs/FILE_FORMAT.md` are load-bearing project guidance. Read and follow them before changing code.
- `docs/ARCHITECTURE.md` is the source of truth for target boundaries, dependency direction, data flow, concurrency, and storage safety.
- `docs/FILE_FORMAT.md` is the source of truth for the vault contract, entity identity, references, schema, and mutation guarantees.
- Markdown files are canonical. Any index or cache must remain derived, disposable, and rebuildable.
- Do not contradict a recorded decision in `MEMORY.md` without flagging it first.

## Non-Negotiable Contracts

- Markdown files are the source of truth. Never introduce a canonical app database.
- Preserve Markdown bodies and unknown frontmatter keys when changing known fields.
- Entity identity is the exact, case-sensitive, vault-relative path. Do not add hidden UUIDs.
- App-driven moves must update known path references atomically.
- Surface unresolved references and malformed files; never silently discard or repair user content.
- Keep both app shells and the CLI as thin clients over the shared Domain, Markdown, Workspace and Presentation targets appropriate to each client.

## Dependency Direction

Dependencies point inward:

```text
LocalTodoApp --------+                    +-------- LocalTodoIOSApp
                     |                    |
                     +--> LocalTodoWorkspace <---+
                     |           |
                     |           v
                     +--> LocalTodoMarkdown <-------- LocalTodoCLI
                     |           |
                     |           v
                     +----> LocalTodoDomain <---------+

LocalTodoApp ------> LocalTodoPresentation <------ LocalTodoIOSApp
```

- `LocalTodoDomain` contains value types and business rules. It imports no UI, CLI, or YAML package.
- `LocalTodoMarkdown` owns schema translation and filesystem operations.
- `LocalTodoWorkspace` owns portable routes, recurrence editor values, vault-session operations, filters, view preferences, history and recovery checkpoints. The macOS shell currently consumes the shared route/recurrence values while retaining `WorkspaceModel`; the iOS shell composes `WorkspaceSession`. The target imports no SwiftUI, AppKit or UIKit.
- `LocalTodoPresentation` owns shared SwiftUI palette, stylesheet and presentation values without importing either app shell.
- `LocalTodoCLI` owns argument parsing and output formatting only.
- `LocalTodoApp` and `LocalTodoIOSApp` own their platform-specific SwiftUI composition, access lifetime and OS integration only.

Do not create a catch-all `Utils`, `Helpers`, `Manager`, or `Services` module.

## Swift Standards

- Use Swift 6 language mode and complete strict concurrency checking.
- Prefer immutable structs, enums, and pure transformations.
- Introduce protocols only at real boundaries such as filesystem, clock, and process environment.
- Inject dependencies at app or command composition roots; avoid global mutable state and service locators.
- Use typed, actionable errors. Do not force unwrap, force cast, or suppress errors without a documented reason.
- Keep one primary responsibility per file. A 300-line file or 40-line function is a warning to extract behavior, not a target.
- Name by domain intent. Comments explain non-obvious constraints, not syntax.
- Avoid compatibility branches until a supported platform or persisted format requires them.

## Testing

- Add or update tests with every behavior change.
- Use Swift Testing for domain and storage tests. Reserve XCTest for UI automation or APIs that require it.
- Test the file contract with fixtures, including unknown keys, malformed YAML, external moves, conflicts, and atomic-write failures.
- Test dates with an injected calendar, timezone, and clock.
- Add regression tests before fixing a reproduced bug.

For pure documentation changes, do not run `make check`. Review the changed text for accuracy and consistency, verify relevant links and examples, and run `git diff --check` before handing work back or committing. Documentation includes Markdown guides and agent instructions; changes to executable code, build configuration, dependencies, scripts or test fixtures are not pure documentation changes.

For changes beyond pure documentation, run the complete quality gate before handing work back or committing:

```bash
make check
```

- `make check` regenerates the Xcode project, checks formatting/lint and release scripts, runs Swift package, macOS app, shared iOS and phone/tablet UI tests, then builds both app schemes. All stages must pass; `swift build` or `swift test` alone does not compile the apps.
- Run `make build` for a focused unsigned app-build check. The generated `LocalTodo.xcodeproj` is ignored by Git; change `project.yml` for project settings and regenerate with `make generate` after pulling source changes.
- Run `make build-ios` for a focused unsigned iOS Simulator build. `make test-ios` runs the shared/mobile suites on the configured phone simulator and the adaptive-workspace UI check on an available iPad simulator.
- When investigating Xcode Build/Run failures, also validate the normal signed build used by Xcode, without `CODE_SIGNING_ALLOWED=NO`:

  ```bash
  make generate
  xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug -destination 'platform=macOS' clean build
  ```

- Record the Xcode version, commands and results in the PR or handoff. Distinguish build validation from launch/UI validation. If a reported failure cannot be reproduced, say so and request the failing command or Xcode diagnostic rather than claiming a fix.

## Design And Accessibility

- Follow the implemented native patterns and design direction in `DESIGN.md`; keep token documentation aligned with the source.
- Preserve keyboard access, visible focus, reduced motion, scalable text, and non-color state cues.
- Keep core interactions familiar. Do not use decorative motion, nested cards, gradient text, or colored side stripes. Native glass is permitted only on navigation/control surfaces on supported macOS/iOS versions, with accessibility and older-system fallbacks; persistent task content stays opaque.

## Commits

Use Conventional Commits with a required scope:

```text
type(scope): concise imperative subject
```

Allowed scopes: `app`, `cli`, `domain`, `markdown`, `skill`, `docs`, `build`, `ci`.

Common types: `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`, `perf`, `style`.

- Keep the first line at or below 72 characters.
- Actual merge commits are exempt from subject format and length checks, so Git-generated merge messages are accepted. Ordinary commits introduced by a merge still require Conventional Commit subjects.
- Use `!` and a `BREAKING CHANGE:` footer for incompatible file-format or CLI changes.
- Keep commits small and cohesive. Do not mix refactors with unrelated behavior changes.
- Install the optional repository hook with `make bootstrap`.
