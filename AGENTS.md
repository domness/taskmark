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

## Session Memory And Error Logs

Maintain `MEMORY.md` as the project decision log. After any significant decision, add an entry with:

- What was decided
- Why
- What was rejected and why

Never contradict a logged decision without flagging the conflict first and explaining why the prior decision may no longer apply.

When the user says "session end", "wrapping up", or "let's stop here", write a session summary to `MEMORY.md` before stopping. Include:

- Worked on
- Completed
- In progress
- Decisions made
- Next session priorities

Maintain `ERRORS.md` as the repeated-attempts log. When an approach takes more than 2 attempts to work, add an entry with:

- What did not work
- What worked instead
- Note for next time

Check `ERRORS.md` before suggesting approaches to similar tasks.

## Permanent Project Facts

These facts are always true for this project. Apply them to every session without exception. If a task conflicts with one of these facts, flag the conflict before proceeding.

- This is Local Todo, an Apple-native, macOS-first, local-first task manager and CLI built with Swift 6.
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
- Keep the app and CLI as thin clients over shared domain and Markdown targets.

## Dependency Direction

Dependencies point inward:

```text
LocalTodoApp ---> LocalTodoMarkdown <--- LocalTodoCLI
      |                   |
      +--> LocalTodoDomain <+
```

- `LocalTodoDomain` contains value types and business rules. It imports no UI, CLI, or YAML package.
- `LocalTodoMarkdown` owns schema translation and filesystem operations.
- `LocalTodoCLI` owns argument parsing and output formatting only.
- `LocalTodoApp` owns SwiftUI composition and platform integration only.

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

Run the quality gate before handing work back:

```bash
make check
```

## Design And Accessibility

- Follow the seed direction in `DESIGN.md`; replace placeholders only after implementation establishes real tokens.
- Preserve keyboard access, visible focus, reduced motion, scalable text, and non-color state cues.
- Keep core interactions familiar. Do not use decorative motion, nested cards, glass effects, gradient text, or colored side stripes.

## Commits

Use Conventional Commits with a required scope:

```text
type(scope): concise imperative subject
```

Allowed scopes: `app`, `cli`, `domain`, `markdown`, `skill`, `docs`, `build`, `ci`.

Common types: `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`, `perf`, `style`.

- Keep the first line at or below 72 characters.
- Use `!` and a `BREAKING CHANGE:` footer for incompatible file-format or CLI changes.
- Keep commits small and cohesive. Do not mix refactors with unrelated behavior changes.
- Install the optional repository hook with `make bootstrap`.
