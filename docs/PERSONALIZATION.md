# macOS Personalization

## Task Rows And Context Actions

Click anywhere in the task content to the right of its completion control to open editing. Right-click a task for Duplicate, Delete and Copy actions. The **Task** menu exposes the same actions for the selected task through native keyboard menu navigation. Actions operate on one task at a time.

- **Duplicate Task** saves valid pending edits, creates a collision-safe sibling `-copy.md` path and adds “(Copy)” to the title. Notes, checklist state, recurrence, organization, priority, dates and unknown frontmatter are retained. Creation/update timestamps are fresh. Done/canceled copies start in Inbox with no completion timestamp; other statuses are retained. Duplicate is undoable.
- **Delete Task** saves pending edits before deleting. Use **Edit → Undo Delete Task** to restore the exact original Markdown bytes, including unknown fields and formatting; Redo deletes them again. Recovery is session-local native history, not system Trash: restore before switching vaults or quitting. External changes invalidate history, and occupied restoration paths are never overwritten.
- **Copy Title**, **Copy Markdown**, and **Copy Vault-Relative Path** have explicit meanings. Markdown includes frontmatter and notes. Invalid/conflicting pending edits must be resolved before copying or mutating.

## Sidebar Order

Drag a project to an insertion position within Projects to reorder it, including the beginning or end of the section; areas work independently. This uses the native sidebar list's move interaction. Right-click for **Move Up**, **Move Down**, or **Restore Default Order** (also accessible through native contextual-menu keyboard navigation). Task drags onto a collection still assign the task rather than reordering collections.

Order lives in macOS UserDefaults under `sidebar-order.<standardized-vault-path>` with independent project/area arrays. It is device-local presentation, not vault data. Newly discovered and externally moved paths append in exact path order. Missing paths are ignored. Inactive projects remain in the separate review section and cannot be reordered there; their saved position is retained until a subsequent active-section reorder omits them. Areas retain existing navigation membership, including archived areas. Restore Default Order returns that section to exact-path sorting. No Markdown files are moved or renamed.

## Native Stylesheet

Create `.config/style.css` inside the vault. The app reads it on opening and during the existing two-second refresh loop. It never writes or repairs the stylesheet. Missing files use built-in appearance; any unsupported selector, property, malformed declaration or invalid value rejects the whole stylesheet and uses built-in appearance. A warning icon appears on View Options, whose **Stylesheet Issue…** action explains the problem.

Turn off **View Options → Appearance → Use Vault Stylesheet** or **Settings → Theme → Apply vault stylesheet** to use the selected built-in theme. This preference persists on this Mac across launches and vault switches. Settings also provides System/Light/Dark appearance and Local Todo, Slate, Forest and Sand palettes. See [SETTINGS.md](SETTINGS.md) and the full [theme guide](THEMES.md).

```css
/* Base tokens apply to both appearances. */
:root {
  --accent: #3265ad;
  --priority-1: #c83242;
  --priority-2: #b96712;
  --priority-3: #3265ad;
  --task-font-size: 14px;
  --row-spacing: 4px;
}

:root[data-appearance=dark] {
  --accent: #88b9ff;
  --priority-1: #ff8792;
  --priority-2: #ffb765;
  --priority-3: #88b9ff;
}
```

Supported selectors are exactly `:root`, `:root[data-appearance=light]`, and `:root[data-appearance=dark]`. Rules and duplicate declarations apply in source order for each applicable appearance: put overrides after base rules. Block comments and whitespace are accepted; a final semicolon is optional.

| Token | Accepted value | Native effect |
| --- | --- | --- |
| `--accent` | `#RRGGBB` | SwiftUI control tint |
| `--background` | `#RRGGBB` | Main task-list and Settings detail surfaces |
| `--sidebar-background` | `#RRGGBB` | Workspace and Settings sidebars |
| `--inspector-background` | `#RRGGBB` | Task/project inspector surface |
| `--priority-1` / `--priority-2` / `--priority-3` | `#RRGGBB` | Incomplete task completion indicator and priority label |
| `--task-font-size` | `11px`–`24px`, decimals allowed | System task-title font, scaled relative to body text |
| `--row-spacing` | `2px`–`16px`, decimals allowed | Space between task title and metadata |

`px` values map to native logical points. There is no browser CSS engine: arbitrary selectors, layout rules, imports, URLs, variables, named colors and media queries are unsupported. Titles, focus rings and selection retain native semantics; custom surface colors override the selected palette only where supplied. Check custom colors against your preferred appearance and contrast settings.

The entry point is case-sensitive, UTF-8, at most 64 KiB, and cannot have symlink components below the vault root. `.config/` remains available for typed Markdown entities; it is not a newly reserved directory. `.localtodo/config.yml` remains the vault manifest.

## Validation — 2026-09-17

- Toolchain: Xcode 27.0 (`27A266a`).
- `make format && make check`: passed after the native sidebar-reordering correction. Formatting and strict lint were clean; 118 Swift package tests and 75 macOS app tests passed; the generated LocalTodoApp Debug scheme built successfully with `CODE_SIGNING_ALLOWED=NO`. Regression coverage includes moving the first project to the end and back, order persistence, stale source orders/sessions, and invalid insertion indices.
- `git diff --check`: passed.
- Interactive UI evidence: not completed. The macOS System Events inspection timed out. Small-window layout, title/metadata/blank-area clicks, both drag payloads, VoiceOver, and light/dark/increased-contrast appearance still need hands-on acceptance. Automated tests above establish model/storage behavior and build validity, not live gesture or visual verification.
