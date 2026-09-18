# Settings

Open **Taskmark → Settings…** or press **Command-comma**. The native Settings window has General and Theme sections. Changes apply immediately; there is no Apply button. Settings uses the same appearance as the main window.

With multiple vault windows, device-local preferences apply to all of them. Vault-specific timezone and stylesheet controls use the most recently active vault window; the timezone description identifies its vault. Closing that window selects another open workspace, or shows no active vault if all are closed.

The window opens at 760 × 620 logical points and can be resized, with a 700 × 560 minimum. Both sections align short content to the top of the right-hand panel and scroll when content exceeds the available height.

`SettingsWindowResizing` enables the underlying NSWindow's native resizable style after scene setup. SwiftUI's `.contentMinSize` controls sizing constraints but did not, by itself, make this Settings scene user-resizable. `SettingsWindowTests` opens the actual scene and verifies its style, upper size bounds and expanded content size.

Settings uses a fixed 170-point sidebar beneath a compact native titlebar. The two sections remain visible without a sidebar-collapse toolbar row or its extra top inset. Window-button positions remain system-managed.

## General

| Setting | Choices / default | Scope and effect |
| --- | --- | --- |
| Start week on | Any weekday; Monday | Calendar pickers and the “Next week” suggestion. “Later this week” never crosses the chosen week boundary. Weekend suggestions remain Saturday/Sunday. This presentation choice does **not** change shared recurrence calculation boundaries. |
| Date format | System (default), YYYY-MM-DD, DD/MM/YYYY, MM/DD/YYYY | Task-row dates, date-picker buttons/suggestions and inspector file timestamps. System uses the Mac's locale. Exact typed date entry, filters' stored dates, Markdown and CLI formats remain ISO. |
| Time format | System (default), 12-hour, 24-hour | Live Settings preview and Created/Updated file timestamps in the task inspector. Tasks still have date-only scheduled/deadline fields; this adds no task-time schema. |
| Time zone | System when absent, or searchable IANA identifier | **Active vault**, saved to `.localtodo/config.yml`, so app/CLI Today membership and recurrence calculations agree. No vault: control unavailable. |
| Initial view | Today (default), Inbox, Next, Upcoming, Waiting, Someday, All Tasks, Search | Applied on vault opening, including app restoration and switching vaults. Changing it does not navigate away from current work. |

All settings except time zone are device-local UserDefaults keys under `preferences.`. `AppPreferences` is an observable, composition-root-owned dependency with injectable defaults for tests. Unknown stored enum values fall back to defaults rather than failing startup. Initial view/appearance/theme choices persist independently.

### Time-zone safety

The Markdown target owns manifest reads and writes (`VaultStore+Configuration.swift`). It validates schema and IANA identifiers, rejects symlink components and coordinator remaps, compares the entire file's revision, preserves unknown YAML values, and atomically replaces the manifest. Selecting System removes the timezone key. Formatting/comments can normalize. Existing task files and their date values are not rewritten.

Dirty or conflicting drafts must finish saving before changing the time zone. An in-flight timezone save disables workspace editing and blocks vault switching and termination until it finishes. Failures leave the old manifest and selected zone intact, and appear inline with **Reload Time Zone**. Reload before retrying an external-change conflict. Unrelated task undo history, including deletion recovery, survives a successful timezone change.

## Theme

- **System / Light / Dark** controls appearance independently of the chosen palette. System follows macOS. Native controls, sheets, popovers, editors and text use the resolved appearance.
- **Taskmark, Slate, Forest, Sand** each provide paired light/dark palettes. Selection applies immediately to sidebar, list, inspector and Settings surfaces and control accents.
- **Apply vault stylesheet** enables `.config/style.css` overrides on top of the selected theme. This preference is persistent on this Mac. Missing/invalid styles fall back to the selected built-in theme. The Settings section shows parse diagnostics and provides Reveal Vault and Reload Stylesheet actions.

See [THEMES.md](THEMES.md) for every built-in token, custom-theme examples, override precedence and implementation extension points.

## Verification

Behavior coverage lives in `AppPreferencesTests`, `WorkspaceSettingsTests`, `CalendarDateFieldTests` and `ConfigurationMutationTests`. The full quality gate is `make check`; it includes the unsigned Debug app build. Settings behavior/build checks do not establish full-window visual correctness.

`SettingsRenderingTests` is an opt-in visual capture utility. It renders isolated native windows with temporary preferences/vaults for both sections and every light/dark palette. On a Mac with window capture permission, set `TEST_RUNNER_LOCALTODO_SETTINGS_CAPTURES` to an existing writable directory and run the app test target:

```sh
TEST_RUNNER_LOCALTODO_SETTINGS_CAPTURES=/absolute/existing/directory \
  xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp \
  -configuration Debug -destination 'platform=macOS' test \
  -only-testing:LocalTodoAppTests CODE_SIGNING_ALLOWED=NO
```

Full-window capture was unavailable in the implementation environment. NSHostingView bitmap capture omitted native vibrancy layers and was rejected as full UI evidence; `screencapture` reported “could not create image from window.” Live Settings-menu navigation, keyboard/VoiceOver use, native sidebar selection contrast and System appearance switching remain manual acceptance checks.

## Related Guides

- [Themes](THEMES.md): built-in palette values, stylesheet syntax and extension points.
- [Personalization](PERSONALIZATION.md): task/sidebar ordering, context actions and editing interactions.
- [Design](../DESIGN.md): native typography, surfaces, controls and accessibility direction.
- [Roadmap](ROADMAP.md): implemented work and remaining native-window validation.
