# Native Themes And Custom Stylesheets

Taskmark is SwiftUI/AppKit, not a web view. Themes customize native appearance tokens; CSS is a deliberately small input syntax, not a browser layout engine.

## Appearance And Precedence

1. **Settings → Theme → Appearance** selects System, Light or Dark. System follows the Mac, while explicit modes override the application's window appearance.
2. The selected built-in theme provides background/sidebar/inspector surfaces and an accent for that appearance, plus its interface font and default base size.
3. If **Apply vault stylesheet** is enabled, valid `.config/style.css` tokens override only those supplied. Other tokens retain the built-in palette or native control default.
4. Within a stylesheet, matching rules/declarations apply in source order. Put appearance overrides after `:root` rules.

The appearance choice and palette are independent. Choosing Forest while in Dark mode selects Forest's dark palette. Preview tiles show built-in themes without custom overrides; a stylesheet may visibly override a selected palette. Disable the stylesheet to see the unmodified built-in theme.

Native primary/secondary text, focus, selection, disabled state, control fills and separators retain system semantics. Priority indicators keep P1 red/P2 orange/P3 blue by default, with explicit labels; P4/unset stay neutral and completed tasks use secondary styling. Themes do not change task order or content.

## Built-In Tokens

All colors are sRGB `#RRGGBB`. `AppTheme.swift` is the implementation source of truth.

| Palette / appearance | Background | Sidebar | Inspector | Accent |
| --- | --- | --- | --- | --- |
| Taskmark / Light | `#f7f8fa` | `#edf0f3` | `#f1f3f6` | `#365f99` |
| Taskmark / Dark | `#202226` | `#191b1f` | `#25282d` | `#92b8ee` |
| Slate / Light | `#f1f5f9` | `#e4ebf3` | `#eaf0f7` | `#315e9d` |
| Slate / Dark | `#1c2532` | `#151d29` | `#232e3d` | `#91bdf4` |
| Forest / Light | `#f2f7f3` | `#e4ede6` | `#ebf2ed` | `#306b49` |
| Forest / Dark | `#1d2922` | `#162019` | `#25332a` | `#91c9a3` |
| Sand / Light | `#faf6ef` | `#efe7da` | `#f4ede2` | `#8b562c` |
| Sand / Dark | `#2b2520` | `#211c17` | `#342d25` | `#dfb486` |
| Catppuccin / Light (Latte) | `#eff1f5` | `#dce0e8` | `#e6e9ef` | `#8839ef` |
| Catppuccin / Dark (Mocha) | `#1e1e2e` | `#11111b` | `#181825` | `#cba6f7` |
| Dracula / Light (Alucard) | `#fffbeb` | `#f4f0e1` | `#f8f4e5` | `#644ac9` |
| Dracula / Dark | `#282a36` | `#22242e` | `#2e303d` | `#bd93f9` |

Select **Catppuccin** or **Dracula** in Settings, then choose Light/Dark (or System) to resolve the variant. Configuration stores `theme: catppuccin` or `theme: dracula` independently of `appearance`; both choices use the same stylesheet precedence as the original palettes.

### Community Palette Sources

- [Catppuccin](https://github.com/catppuccin/catppuccin#-palette): Latte and Mocha use upstream Base for the main background, Crust for the sidebar, Mantle for the inspector and Mauve for the accent, following the upstream [pane guidance](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md).
- [Dracula and Alucard](https://github.com/dracula/dracula-theme#color-palette-oss): use the open-source Background and Purple colors. Secondary panes are Taskmark adaptations: Alucard blends its Foreground into Background at 5% (sidebar) and 3% (inspector); Dracula darkens Background by 15% for the sidebar and blends Current Line into Background at 20% for the inspector, rounded to sRGB bytes. These are surface adaptations, not upstream palette entries.

Both palettes are MIT-licensed; attribution and license notices are in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). Native text and semantic priority colors remain system-owned as described above.

### Theme Typography

| Theme | Interface family | Default interface base size |
| --- | --- | --- |
| Taskmark, Slate, Forest, Sand | Native system font (SF on macOS) | 13 points |
| Dracula (Alucard / Dracula) | Inter | 13 points |
| Catppuccin (Latte / Mocha) | Figtree | 14 points |

The theme family and base size apply at the workspace and Settings roots, including sidebars, headers, inspectors, sheets, app-authored controls and editors. Explicit headings, metadata and notes retain their relative native semantic sizes and weights. Catppuccin's extra point therefore applies across the app-authored window rather than only to task titles. Theme preview samples show each theme's own typography.

Code and exact file paths retain native monospaced typography; native menus, system dialogs and system-owned control text retain platform behavior. The font follows the selected theme in each vault window and its Settings context. Fonts are theme defaults, with no separate font picker or CSS font-family token in this version.

Inter and Figtree are bundled locally as upright/italic variable TrueType fonts, including real bold and italic faces for Markdown emphasis. They work offline without installation. The SIL Open Font License 1.1 notices ship with the fonts; see [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) and the pinned source details in `Apps/LocalTodoApp/Resources/Fonts/README.md`.

The existing `--task-font-size` token name is retained for stylesheet compatibility, but its value now overrides the whole interface base size, including appearance-specific values. Disabling the stylesheet restores the selected theme's size. Title/metadata spacing defaults to 3 points. Appearance tokens color broad native surfaces, not decorative borders or nested cards.

## Custom Theme Example

Create the optional file `<vault>/.config/style.css`:

```css
/* A cool ink theme, layered on whichever built-in palette is selected. */
:root {
  --task-font-size: 14px;
  --row-spacing: 5px;
}

:root[data-appearance=light] {
  --background: #f4f7fc;
  --sidebar-background: #e7edf6;
  --inspector-background: #edf2f9;
  --accent: #345f9b;
  --priority-1: #ba3147;
  --priority-2: #9b5a13;
  --priority-3: #345f9b;
}

:root[data-appearance=dark] {
  --background: #1c2532;
  --sidebar-background: #161e2b;
  --inspector-background: #243044;
  --accent: #96c0f8;
  --priority-1: #ff95a4;
  --priority-2: #edbf81;
  --priority-3: #96c0f8;
}
```

| Property | Valid values | Applied to |
| --- | --- | --- |
| `--background` | `#RRGGBB` | Main task-list and Settings detail surfaces |
| `--sidebar-background` | `#RRGGBB` | Workspace and Settings navigation surfaces |
| `--inspector-background` | `#RRGGBB` | Task/project inspector surface |
| `--accent` | `#RRGGBB` | SwiftUI interactive control tint |
| `--priority-1`, `--priority-2`, `--priority-3` | `#RRGGBB` | Incomplete-task completion indicators and priority labels |
| `--task-font-size` | `11px`–`24px`, decimals allowed | App-authored window typography base size; default 14 for Catppuccin, 13 otherwise |
| `--row-spacing` | `2px`–`16px`, decimals allowed | Task-title/metadata gap |

Selectors are exactly `:root`, `:root[data-appearance=light]` and `:root[data-appearance=dark]`. Tokens are case-sensitive. Whitespace, block comments and optional final semicolons are supported. `px` maps to native logical points. CSS imports, URLs, arbitrary selectors, variables, named/alpha colors, media queries and layout properties are unsupported and produce a diagnostic.

### Reload And Recovery

- The entry point is case-sensitive UTF-8, no more than 64 KiB; symlink components below the root are rejected. `.config/` is reserved for configuration, styles and saved filters, not task entities.
- Reads happen on opening the vault and its existing approximately two-second refresh, or through Reload Stylesheet. No app action writes or repairs the stylesheet.
- Any invalid or unsupported declaration rejects the whole file. The selected built-in theme stays usable; Theme Settings and the task-list View Options warning expose the diagnostic. A missing stylesheet simply uses the built-in theme.
- Disabling Apply vault stylesheet persists in the vault's `.config/config.yml` and applies on every machine that opens that vault. It does not delete the file. Each vault retains independent appearance choices; app/CLI task semantics and vault timezone remain unaffected.
- Custom colors are user-controlled. Provide paired light/dark values, keep native text legible, test selected and disabled states and Increase Contrast, and preserve at least 4.5:1 body-text contrast. There is no automatic contrast certification or silent palette rewriting.

## Extending The Implementation

Source paths below are relative to `Apps/LocalTodoApp/Sources/`. For window composition and behavior, see [Settings](SETTINGS.md); for ordering and task interactions, see [Personalization](PERSONALIZATION.md).

- `Settings/AppPreferences.swift`: observable per-vault choices projected from canonical configuration. Workspace-owned autosave persists changes through `LocalTodoMarkdown`; use temporary vaults in tests rather than machine defaults. Malformed stored preferences are diagnosed and not silently reset.
- `Settings/AppTheme.swift`: add palette cases here, each with explicit light/dark tokens and a useful preview label. The Settings grid derives from `allCases`. Also update `Sources/LocalTodoMarkdown/VaultPreferenceValidation.swift` and the file-contract theme values so app and CLI can reopen saved choices.
- `Workspace/VaultAppearance.swift`: validates the CSS subset and merges overrides. Add new tokens to its allowlist with validation, tests and an entry in this document; never silently accept unsupported declarations.
- `Settings/AppAppearanceModifier.swift`: applies preference-driven native appearance at **both scene roots**, propagates calendar/date-format/theme environments, and defines `ThemeSurface` for explicit semantic surfaces. Do not force every text/control fill to a custom color; macOS still owns focus, selection and form-control states.
- `Settings/ThemePreview.swift`: displays the same built-in tokens as the workspace. Keep the textual selected state and checkmark; color alone is insufficient.
- `Settings/ThemeTypography.swift`: maps themes to bundled families, scales native semantic roles from the effective interface base size, and supplies `themeFont` for explicit roles. `project.yml` copies the Fonts resource folder and generates the `ATSApplicationFontsPath` Info.plist entry for app-local registration.
- New surfaces should opt into the appropriate surface token and otherwise inherit native appearance. Use `CalendarDateField` or the shared display formatter for dates; persisted values remain ISO.

Tests cover paired tokens, override precedence, disabling overrides, malformed-file fallback, reload, persistence, bundled font resolution (including bold/italic and license resources), and inherited/semantic native editor family and size updates across theme switches. Full visual contrast and system-appearance interaction still require native window testing; build success alone is not that evidence.
