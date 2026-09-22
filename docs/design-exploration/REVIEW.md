# Taskmark: a quieter native workspace

**Original discussion proposal · 21 September 2026**

Concept B was selected and implemented in native SwiftUI, then refined so a single task-row click opens the inspector without entering edit mode. This document preserves the original comparison and is not a current interaction specification; `DESIGN.md` describes implemented behavior. See [native screenshots](native/README.md) for implementation evidence. The HTML remains an exploratory study with intentionally different gestures.

## Open the mockups

Open `index.html` directly in a browser, or serve the repository root and visit `/docs/design-exploration/`. The prototype uses no external libraries, services or network fonts. It references the existing bundled fonts and icon, so keep it inside this checkout.

- **A — Quiet split:** `index.html?concept=split`
- **B — Focused canvas:** `index.html?concept=focus` — recommended
- **C — Inline workspace:** `index.html?concept=inline`
- Example themed state: `index.html?concept=inline&palette=catppuccin&dark=true`

Switch concepts, all six palettes, light/dark and reduced transparency. Try Today/project navigation, selection, inspector visibility, inline notes, checklists, completion, search, metadata visibility and task capture. All mutations are ephemeral example data. The property rows illustrate layout, not working metadata pickers. Sidebar disclosures show example categories, not a complete navigation implementation. The macOS window controls are illustration only.

## Review basis

This review originally compared the SwiftUI composition, `DESIGN.md`, theme documentation and decision log against a supplied Things reference before native implementation captures existed. The repository now includes [full WindowServer captures](native/README.md). Browser renders still verify only the proposals; their blur is not Apple's Liquid Glass renderer.

The reference succeeds through a quiet sidebar, a prominent page title, flat task rows, selective metadata, clear section rhythm and a wide opaque content plane. Its clarity does not depend on translucent task cards. Taskmark already shares several foundations: native navigation, separator-free rows, rendered Markdown, contextual metadata preferences and a collapsible inspector.

## Where the current interface gets busy

| Current implementation | Design consequence | Proposed improvement |
| --- | --- | --- |
| `Tasks/TaskListView.swift`: route heading, persistent search field, capture and options share a compact header; title can disappear in a constrained layout | The view name competes with controls and loses hierarchy precisely when space is tight | Give the route a stable content heading; use compact, discoverable search in the command area |
| `Tasks/TaskRow.swift`: planning metadata is always shown; project, area and tags default on in most routes | A task can read as a title plus a second record of fields | Use the current project/area grouping to remove repeated context; reserve trailing metadata for deadlines, overdue state and recurrence; expose extra details in View Options |
| `Tasks/TaskInspectorView.swift`: grouped Form with status, priority, dates, organization and repeat before notes | The task's actual content is visually subordinate to its properties | Title → notes/checklist → compact, aligned properties. Keep Project, Area, Tags and Repeat directly visible |
| `Workspace/SidebarView.swift`: eight Focus routes plus filters, projects, areas, tags and five priorities | Many destinations carry comparable prominence | Keep daily routes first; retain Projects; collapse less-frequent sections with discoverable disclosures |
| `Settings/AppAppearanceModifier.swift`: broad surfaces are explicit opaque token fills | Palette changes affect the whole window, but cannot create native material hierarchy | Keep content opaque; allow system-owned sidebar/toolbar materials with theme-aware tinting |
| `Settings/ThemeSettingsView.swift`: paired palette previews separate from the actual workspace | Small previews cannot show how busy a real task list feels | Keep existing settings controls; assess each theme on representative complete windows as shown here |

Source paths in this table are relative to `Apps/LocalTodoApp/Sources/`.

## Three alternatives

### A — Quiet split

Preserve the current selection-to-inspector interaction. Recompose the inspector as a flat task document, put notes first, and keep its properties in a compact label/value list. The content and inspector retain their existing distinct surface tokens.

**Strength:** lowest behavioral risk; suited to processing many tasks and changing metadata repeatedly. **Cost:** three columns still constrain title width. The mockup uses a roughly 306-point inspector to demonstrate the tradeoff, not to replace the app's resizable 280–480-point range.

### B — Focused canvas — selected, then refined

The original proposal used sidebar + task canvas as the normal reading state and required an explicit action to open details. The shipped refinement keeps the focused two-column default but opens the inspector on a task-row click; the toolbar still toggles it. A readable canvas width and a substantial heading carry the interface. Project notes live immediately under the project heading.

**Strength:** greatest clarity gain with relatively little new UI machinery. A's inspector remains available for detailed editing. **Cost:** opening details becomes a deliberate action. The mockup's double-click opens details, but this conflicts with Taskmark's existing double-click inline title editing: **for implementation, retain double-click title editing and use the inspector toggle / existing Command-E action to open details.** This prototype gesture is exploratory, not an approved replacement.

### C — Inline workspace

Expand one selected task into notes, checklist and properties within the list. The expansion shares the opaque content surface; it is not a floating glass card. The normal inspector is absent in this study.

**Strength:** closest to Things' direct, in-context task editing. **Cost:** expansion moves surrounding rows and makes native selection, title editing, Custom-order drag tracking and accessibility more involved. Reuse workspace-owned drafts; never introduce view-owned document copies. This is a second-stage interaction prototype, not the first implementation recommendation.

## Theming: preserve the investment

Current options are already broad enough:

| Palette | Light / dark | Font |
| --- | --- | --- |
| Taskmark | Paper / Night | System, 13-point base |
| Slate | Cool light / blue-black | System, 13-point base |
| Forest | Pale green / deep green | System, 13-point base |
| Sand | Warm paper / brown-black | System, 13-point base |
| Catppuccin | Latte / Mocha | Bundled Figtree, 14-point base |
| Dracula | Alucard / Dracula | Bundled Inter, 13-point base |

Appearance is independently System/Light/Dark. Vault stylesheets merge over the chosen palette. Existing supported overrides are surfaces, accent, P1–P3 colors, the window-wide base font size (`--task-font-size`, 11–24 points) and the title/metadata gap (`--row-spacing`, 2–16 points). They **cannot** change column composition, row padding, heading hierarchy, control placement or materials.

The mockup uses the current exact palette surface/accent values and local fonts; text/control colors are browser approximations of semantic native roles. Its proposed heading and row sizes are not a pixel-perfect port of existing `ThemeTypography`. Do not infer that Catppuccin or Dracula have been redesigned or that existing CSS supports this layout.

**Recommendation:** separate material policy from palette. Keep all six palettes. Let the OS supply appropriate native chrome, let the palette supply the content surface and accent, and use solid theme surfaces when accessibility or the older OS requires them. Start with automatic system behavior rather than introducing a permanent new appearance switch. The mockup's Reduce transparency toggle is a comparison aid for the system accessibility behavior.

## Where Liquid Glass belongs

- **Navigation and commands:** native sidebar/titlebar treatment and small related toolbar groups. Start with standard SwiftUI/AppKit components and an SDK-native toolbar before adding custom effects.
- **Task content:** opaque and stable, including notes, checklists, expanded rows and inspector content. No glass behind task text, no glass on each metadata chip, no glass-on-glass stacking.
- **Themes:** translucent chrome cannot guarantee exact RGB appearance over every desktop background. Preserve exact token colors for solid content and fallback surfaces; avoid letting an opaque full-pane overlay defeat the native material.
- **Availability:** Taskmark supports macOS 15+. New Liquid Glass APIs require availability-gated macOS 26+ implementation; macOS 15 keeps its standard native materials and the same layout. A SwiftUI material/blur fallback should not be described as equivalent Liquid Glass.
- **Accessibility:** respect Reduce Transparency, Increase Contrast, Reduce Motion and native inactive-window behavior. Keep visible keyboard focus and semantic labels. Inspect light/dark over both plain and busy desktops. The HTML study does not establish native accessibility or contrast acceptance.

Reference: Apple's [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) and [Materials](https://developer.apple.com/design/human-interface-guidelines/materials). API selection and final native behavior require a SwiftUI proof on the supported OS versions.

## Resolution Of The Original Open Decisions

1. **Material policy:** adopted. System-provided glass is limited to navigation/control surfaces on supported macOS versions; persistent task content stays opaque with accessibility and older-system fallbacks.
2. **Selection:** refined after implementation. A row click opens details in reading mode; double-click still edits the title inline, Command-E focuses the inspector title, and Custom-order gestures remain native.
3. **Inspector order:** adopted. Notes and checklists precede properties while Project, Area, Tags and Repeat stay directly available.
4. **Header:** adopted. Search, capture and view options remain associated with the task column; the inspector toggle stays at the trailing window edge.
5. **Metadata:** adopted with route-specific defaults. Grouping suppresses redundant labels while both planning dates remain available in details and overdue warnings remain explicit.

No Evening field, project subsections, calendar integration, progress tracking or new entity hierarchy is implied by these studies. The section headings use existing project grouping. Synthetic counts describe only the example tasks.

## Suggested delivery order

1. Adopt the shared visual foundation: stable page title, calmer task metadata, optional sidebar disclosures, quieter controls and notes-first inspector. Validate on macOS 15 and 26+ with the existing native components.
2. Make B's focused state the default if approved; preserve A's inspector as the optional detailed mode. Add native glass only to the appropriate chrome, with system accessibility fallbacks.
3. Evaluate C separately with native keyboard, mouse and VoiceOver trials, especially Custom ordering, editing focus, autosave, conflicts and long Markdown bodies.

At each stage: long/wrapped titles; zero and hundreds of tasks; missing references; overdue and recurring tasks; pending saves/conflicts; 840-point minimum window and larger windows; larger theme text; all six light/dark palettes; selected/unselected and active/inactive states. Keep errors and conflict actions visible even in the quiet layout. The current autosave/storage/history boundaries should remain intact.

## Proposed sizing, not a new token contract

- Sidebar near the existing 220-point ideal.
- Opaque content reading width approximately 620–720 points when the inspector is closed.
- Page heading approximately 26–30 points; task text 13–14; supporting context 11–12, scaled by the selected theme.
- Ordinary rows around 36–44 points, growing for wrapped text or extra metadata. Group breaks around 24–32 points.
- Toolbar is subordinate to the page title; section headings use restrained accent plus text hierarchy.

These values guide a native prototype. They do not add stylesheet keys or override native minimum targets, text scaling or user column sizes.
