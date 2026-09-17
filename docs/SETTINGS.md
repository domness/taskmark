# Settings

Open **Local Todo → Settings…** or press **Command-comma**. The native Settings window has General and Theme sections. Changes apply immediately; there is no Apply button. Settings uses the same appearance as the main window.

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
- **Local Todo, Slate, Forest, Sand** each provide paired light/dark palettes. Selection applies immediately to sidebar, list, inspector and Settings surfaces and control accents.
- **Apply vault stylesheet** enables `.config/style.css` overrides on top of the selected theme. This preference is persistent on this Mac. Missing/invalid styles fall back to the selected built-in theme. The Settings section shows parse diagnostics and provides Reveal Vault and Reload Stylesheet actions.

See [THEMES.md](THEMES.md) for every built-in token, custom-theme examples, override precedence and implementation extension points.

## Verification

Behavior coverage lives in `AppPreferencesTests`, `WorkspaceSettingsTests`, `CalendarDateFieldTests` and `ConfigurationMutationTests`. The full quality gate is `make check`.

On 2026-09-17, `make format && make check && git diff --check` passed with Xcode 27.0 (`27A266a`): 121 package tests; 84 registered app tests with 83 run and the optional screenshot test skipped; clean strict lint; successful unsigned Debug app build. A separate code-only review's deletion-history finding and documentation gaps were resolved, and the deletion-recovery regression passed. This is build/model/storage evidence, not a full-window visual pass.

`SettingsRenderingTests` is an opt-in visual capture utility. It renders isolated native windows with temporary preferences/vaults for both sections and every light/dark palette. On a Mac with window capture permission, set `TEST_RUNNER_LOCALTODO_SETTINGS_CAPTURES` to an existing writable directory and run the app test target:

```sh
TEST_RUNNER_LOCALTODO_SETTINGS_CAPTURES=/absolute/existing/directory \
  xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp \
  -configuration Debug -destination 'platform=macOS' test \
  -only-testing:LocalTodoAppTests CODE_SIGNING_ALLOWED=NO
```

Full-window capture was unavailable in the implementation environment. NSHostingView bitmap capture omitted native vibrancy layers and was rejected as full UI evidence; `screencapture` reported “could not create image from window.” Live Settings-menu navigation, keyboard/VoiceOver use, native sidebar selection contrast and System appearance switching remain manual acceptance checks.

## Direction contract

**Thesis:** A native, two-section macOS Settings window makes personal defaults and appearance easy to inspect and change without interrupting task work.

**Own-world:** Inherit Local Todo's quiet workbench: system typography, flat native forms, restrained semantic colors and visible keyboard focus. Default, Slate, Forest and Sand each have deliberately paired light/dark surfaces.

**Story:** Choose General for calendar, display and startup behavior; choose Theme for appearance and palettes. Preferences apply immediately and survive relaunch. The vault time zone remains canonical and shared with the CLI.

**First viewport:** A fixed-width left sidebar lists General and Theme. The right side shows a heading and grouped native controls. Theme presents a System/Light/Dark picker followed by four compact selectable previews and custom-stylesheet controls.

**Form:** User-specified native sidebar composition within the existing design system; no concept-seed round applies. Personalization is operated at a desk in both bright and dim conditions, so System is the default with explicit appearance overrides.

**Finish:** unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
