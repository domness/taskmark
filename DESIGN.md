---
name: Taskmark
description: A focused local-first task manager built on transparent Markdown files.
---

# Design System: Taskmark

## 1. Overview

**Creative North Star: "The Quiet Workbench"**

The interface is a precise working surface where tasks, dates, and file-backed structure remain close at hand without competing for attention. Things leads the hierarchy and interaction craft, while file-native details appear only when they help users understand or control their data.

The system is monochrome and adaptive rather than sterile. Contrast, weight, spacing, and restrained tonal layers establish hierarchy in both light and dark environments. Motion responds quickly to input and explains state changes; it never becomes choreography.

The product must not feel like a Jira issue editor. Task entry and review are workflows, not administrative forms.

**Key Characteristics:**
- Monochrome adaptive surfaces with semantic color reserved for meaning.
- Calm hierarchy with dense detail available on demand.
- Familiar controls refined through spacing, typography, and feedback.
- File-native cues that clarify behavior rather than decorate it.
- Responsive across desktop and mobile without diluting power-user workflows.

## 2. Colors

The palette uses adaptive, subtly tinted near-neutrals. The built-in Taskmark tokens below are implemented in `Apps/LocalTodoApp/Sources/Settings/AppTheme.swift`; [docs/THEMES.md](docs/THEMES.md) maintains all palette values and override rules.

### Primary
- **Working Ink**: Native `.primary` and `.secondary` text styles, with system-owned focus/selection/disabled semantics. Control accent is `#365f99` in light mode and `#92b8ee` in dark mode.

### Neutral
- **Paper Surface**: Light background `#f7f8fa`, sidebar `#edf0f3`, inspector `#f1f3f6`.
- **Night Surface**: Dark background `#202226`, sidebar `#191b1f`, inspector `#25282d`.
- **Quiet Rule**: Native dividers and system control boundaries; no custom separator token.

### Named Rules

**The Monochrome Discipline Rule.** Structure the product with tone, spacing, and weight. Introduce semantic hues only when they communicate priority, status, warning, success, or error.

**The Adaptive Surface Rule.** Dark mode is not an inversion. Each theme has its own surface hierarchy and contrast tuning.

## 3. Typography

**Interface Font:** Native system typography (SF on macOS).
**File Paths:** Native monospaced caption styling where exact identity is shown.

**Character:** System text styles provide familiar density, legibility and hierarchy. Task-list title size defaults to 13 logical points and scales relative to body text; the stylesheet may set a bounded 11–24-point value.

### Hierarchy
- **Empty states**: Native `ContentUnavailableView` hierarchy.
- **Headline**: Route/project headings and inspector title fields use `.headline`.
- **Task titles**: Scaled system font in rows; neutral color with completion strikethrough. Incomplete overdue tasks use semantic red plus an explicit Overdue warning label; only planning dates before the vault-local day qualify.
- **Body**: `.body` for notes and editors; prose line lengths should remain comfortable as views expand.
- **Metadata**: `.caption` and secondary styling in rows; `.callout` for tag tokens and supporting Settings content.

### Named Rules

**The One Family Rule.** Hierarchy comes from size, weight, spacing, and numeric features, never from decorative font pairing.

## 4. Elevation

The system is flat by default. Tonal surface changes and native dividers establish structure. Menus, popovers and drag previews use platform presentation; there is no app-defined shadow/elevation token system.

### Named Rules

**The Working Plane Rule.** Persistent content shares one visual plane. Never stack decorative cards or use shadow to compensate for weak hierarchy.

## 5. Components

- **Workspace**: Sidebar, task-list header/list and collapsible inspector. Inbox appears above Today. The inspector toggle belongs to the trailing window toolbar; capture/search/display controls belong to the list header.
- **Window sizing**: New vault windows default to 1120×720 points and respect the workspace minimum. The sidebar has a 180–320-point range (220 ideal); the inspector belongs to the detail column and retains its 280–480-point range (340 ideal). Flexible detail/inspector content accepts the allocated width instead of driving the split beyond the window during vault loading.
- **Selection and editing**: A row's title/metadata area selects and opens details with list focus. Command-E explicitly focuses the title. Inspector task titles are placeholder-only multiline fields, expanding up to six visible lines. Date metadata participates in intrinsic row sizing.
- **Organization**: Project, Area, Tags and Repeat are always visible in the task inspector. Tags use removable wrapping tokens and an add popover; advanced recurrence fields appear only when relevant to the selected mode. This direct-access inspector is the user-requested exception to progressive metadata disclosure.
- **Markdown**: Task rows render inline title formatting while preserving selection and drag gestures. The inspector retains the source title field with a selectable, link-enabled preview for formatted titles. Notes use a native Edit/Preview segmented control; preview blocks use system typography and selectable text, with no web view or remote image loading.
- **Dates**: Compact scheduled/deadline controls open native popovers with suggestions, exact ISO entry and a graphical calendar.
- **Ordering**: Native List insertion gestures reorder collections and tasks in Custom mode. Automatic task sorts permit assignment drags to sidebar collections.
- **Settings**: Fixed 170-point native sidebar beneath a compact titlebar; grouped General controls and a scrollable Theme grid.

Native controls own interaction feedback. Any future custom motion should remain functional, respect Reduce Motion and avoid decorative transitions; no custom animation-duration token system is implemented.

## 6. Do's and Don'ts

### Do:
- **Do** make capture the visually dominant action without turning every screen into a form.
- **Do** preserve strong text and component contrast in both adaptive themes.
- **Do** keep routine metadata directly accessible in the inspector while reserving advanced controls and file details for their relevant context.
- **Do** use familiar task-manager and platform affordances with precise spacing and focus behavior.
- **Do** communicate every state with text, shape, or iconography in addition to any semantic color.

### Don't:
- **Don't** reproduce the metadata density, process rigidity, or form-like task editing of a Jira issue editor.
- **Don't** introduce hidden storage behavior, opaque database semantics, or surprising file mutations.
- **Don't** enforce GTD through blocking steps or a rigid navigation sequence.
- **Don't** expose every advanced control in the task list or require organization during capture.
- **Don't** use decorative motion, nested cards, glass effects, gradient text, or colored side-stripe borders.
- **Don't** use pure black, pure white, or chroma-free gray as final production colors.

## 7. Implemented macOS Settings And Appearance

The Settings surface inherits the native system font, sidebar navigation, visible keyboard focus and flat working plane. General uses native grouped form controls; Theme uses a segmented appearance picker and four compact selectable previews with text/checkmark selection cues. Preferences apply immediately and autosave to the active vault's `.config/config.yml`; other windows/machines opening that vault reload the same choices. Different vaults may use different palettes. Configuration save errors and conflicts have visible resolution controls.

Appearance is independently System, Light or Dark. Slate, Forest and Sand extend the default Taskmark palette's restrained surface language. All paired token values and extension rules are documented in [docs/THEMES.md](docs/THEMES.md), with code in `Apps/LocalTodoApp/Sources/Settings/AppTheme.swift`.

Native primary/secondary text and control state semantics remain adaptive. Custom vault styles override named surface/accent/priority tokens, task-title size (11–24 logical points, default 13, scaled relative to body), and row metadata spacing (2–16, default 3). They do not replace keyboard focus or selection behavior. Window rendering and contrast require visual acceptance; parser/model/build checks do not establish that evidence.

## 8. App Icon

Taskmark uses the user-supplied folded purple checkmark on a charcoal rounded tile from `Foldmark-Mac-Icon.zip`. The original PNGs, including their transparency and shadows, live in `Apps/LocalTodoApp/Resources/Assets.xcassets/AppIcon.appiconset`. The 512-point 2x slot is the supplied 1024-pixel master; all ten macOS 1x/2x slots are included. `project.yml` selects `AppIcon`, and Xcode compiles the distribution icon into the app bundle. The artwork is supplied by the user, not generated or redrawn in the repository.
