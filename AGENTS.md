# Agent Guidance

## Start Here

Read these files before changing code or product behavior:

1. `PRODUCT.md` for users, purpose, and product principles.
2. `DESIGN.md` for visual and interaction direction.
3. `docs/FILE_FORMAT.md` before reading or writing vault files.
4. `docs/ARCHITECTURE.md` before changing target boundaries.
5. `docs/ROADMAP.md` before expanding scope.

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
