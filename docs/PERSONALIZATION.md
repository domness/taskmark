# macOS Personalization

## Task Rows And Context Actions

Click anywhere in the task content to the right of its completion control to select the task without opening the inspector. Focus stays in the list, where **Backspace** deletes the selection. Use **Command-E** or **Edit Task** to open details and focus the title; double-click the title to edit inline. Backspace inside an inspector text editor edits text normally. Right-click a task for Duplicate, Delete and Copy actions; the **Task** menu also exposes these for the selection. Actions operate on one task at a time.

New Today, Upcoming and Area views group by project. Area/tag row metadata starts hidden; existing saved display preferences remain in effect. Grouped rows omit the repeated project/area label. Today omits a scheduled date only when it equals the vault-local current day; overdue dates, deadlines and recurrence remain visible. Both dates remain editable in details. View Options retains all existing metadata and grouping choices.

The title field uses **Title** only as a placeholder and expands from one to six visible lines. Project, area, token-based Tags and Repeat are always visible. Use the tag **+** button to enter a whole tag or select a suggestion, and **×** to remove one. Commas within a tag name are preserved. Task rows grow or shrink as date metadata is added or removed.

Incomplete tasks past their scheduled date or deadline use red title/date text and an **Overdue** warning label. The boundary is strictly before today in the vault timezone; dates today and completed/canceled tasks are excluded. This warning uses native semantic red independently of priority colors.

- **Duplicate Task** saves valid pending edits, creates a collision-safe sibling `-copy.md` path and adds “(Copy)” to the title. Notes, checklist state, recurrence, organization, priority, dates and unknown frontmatter are retained. Creation/update timestamps are fresh. Done/canceled copies start in Inbox with no completion timestamp; other statuses are retained. Duplicate is undoable.
- **Delete Task** saves pending edits before deleting. Use **Edit → Undo Delete Task** to restore the exact original Markdown bytes, including unknown fields and formatting; Redo deletes them again. Recovery is session-local native history, not system Trash: restore before switching vaults or quitting. External changes invalidate history, and occupied restoration paths are never overwritten.
- **Copy Title**, **Copy Markdown**, and **Copy Vault-Relative Path** have explicit meanings. Markdown includes frontmatter and notes. Invalid/conflicting pending edits must be resolved before copying or mutating.

## Custom Task Order

Choose **View Options → Sort → Custom**, then drag a task to an insertion position. Selecting Custom for the first time starts from the current visible order. Switching to an automatic sort and back restores the remembered order. New/unordered tasks follow ordered tasks in the underlying query order; temporarily hidden tasks retain their saved positions.

Custom order is independent per route and vault, including search and saved-filter views. In grouped lists, moves stay within that project/area group. Orders and their enabled flags live in `.config/config.yml` under `preferences.custom_order`. They travel with the vault, without rewriting entity files or canonical saved-filter sort values. Stale route/session/order/group drags are rejected.

While Custom is active, row drags reorder tasks. Assign a project/area through the inspector, or select an automatic sort to restore task dragging onto sidebar destinations.

## Sidebar Order And Collection Deletion

Drag a project to an insertion position within Projects to reorder it, including the beginning or end of the section; areas work independently. This uses the native sidebar list's move interaction. Right-click for **Move Up**, **Move Down**, or **Restore Default Order** (also accessible through native contextual-menu keyboard navigation). Under automatic task sorts, task drags onto a collection assign the task rather than reordering collections.

Order lives in `.config/config.yml` under `preferences.sidebar_order`, with independent project/area arrays shared across machines. Newly discovered and externally moved paths append in exact path order. Missing paths are ignored. Inactive projects remain in the separate review section and cannot be reordered there; their saved position is retained until a subsequent active-section reorder omits them. Areas retain existing navigation membership, including archived areas. Restore Default Order returns that section to exact-path sorting. No entity files are moved or renamed.

Right-click a collection for **Delete Project** or **Delete Area**. Pending project edits must save successfully first. Tasks, projects and saved filters that reference the collection block deletion with an actionable message; remove those references first. Deletion never cascades. Successful deletion has the same exact-byte, session-local Undo/Redo as task deletion, and deleting the open collection returns navigation to Inbox.

## Native Stylesheet

Create `.config/style.css` inside the vault. The app reads it on opening and during the existing two-second refresh loop. It never writes or repairs the stylesheet. Missing files use built-in appearance; any unsupported selector, property, malformed declaration or invalid value rejects the whole stylesheet and uses built-in appearance. A warning icon appears on View Options, whose **Stylesheet Issue…** action explains the problem.

Turn off **View Options → Appearance → Use Vault Stylesheet** or **Settings → Theme → Apply vault stylesheet** to use the selected built-in theme. This preference is stored with each vault, alongside System/Light/Dark appearance and the Taskmark, Slate, Forest and Sand palette choice. See [SETTINGS.md](SETTINGS.md) and the full [theme guide](THEMES.md).

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
| `--task-font-size` | `11px`–`24px`, decimals allowed | Theme typography base size across app-authored window content |
| `--row-spacing` | `2px`–`16px`, decimals allowed | Space between task title and metadata |

`px` values map to native logical points. The `--task-font-size` name remains supported for compatibility, but scales semantic text throughout the workspace and Settings rather than only task rows. There is no browser CSS engine: arbitrary selectors, layout rules, imports, URLs, variables, named colors and media queries are unsupported. Titles, focus rings and selection retain native semantics; custom surface colors override the selected palette only where supplied. Check custom colors against your preferred appearance and contrast settings.

The entry point is case-sensitive, UTF-8, at most 64 KiB, and cannot have symlink components below the vault root. `.config/` is reserved for metadata, including the manifest `.config/config.yml` and saved filters `.config/filters.md`. Per-view metadata visibility, grouping and automatic sorting are stored under `preferences.views` in the manifest. All preference writes preserve unknown configuration keys, use revision checks, and expose conflicts for explicit resolution.

## Verification

Run `make check` for the full quality gate. Relevant app suites include `WorkspacePersonalizationTests`, `SidebarOrderTests`, `TaskCustomOrderTests`, `TaskTagsTests` and `WorkspaceCollectionDeletionTests`; storage suites cover exclusive restoration and collection-reference protection. `TaskRowLayoutTests` hosts native views to check date-driven row resizing and Backspace routing between the real inspector title field and task list.

These automated checks do not establish full-window visual acceptance or physical drag behavior. Small-window layouts, native drag gestures, VoiceOver and light/dark/Increase Contrast appearance remain hands-on checks in the [roadmap](ROADMAP.md).
