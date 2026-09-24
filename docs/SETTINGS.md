# Settings

Open **Taskmark → Settings…** or press **Command-comma**. The native Settings window has General, Theme and Updates sections. Changes apply immediately; there is no Apply button. Settings uses the same appearance as the main window.

Settings edits the most recently active vault window. Vault choices persist in `.config/config.yml`, so different vaults can have different themes. Windows/machines opening the same vault reload its settings from the shared file. Closing the active window selects another open workspace; without a vault, vault preference controls are disabled. CLI registration is a machine-level control and remains available without a vault.

The window opens at 760 × 620 logical points and can be resized, with a 700 × 560 minimum. Sections align short content to the top of the right-hand panel and scroll when content exceeds the available height.

`SettingsWindowResizing` enables the underlying NSWindow's native resizable style after scene setup. SwiftUI's `.contentMinSize` controls sizing constraints but did not, by itself, make this Settings scene user-resizable. `SettingsWindowTests` opens the actual scene and verifies its style, upper size bounds and expanded content size.

Settings uses a fixed 170-point sidebar beneath a compact native titlebar. Sections remain visible without a sidebar-collapse toolbar row or its extra top inset. Window-button positions remain system-managed.

## General

| Setting | Choices / default | Scope and effect |
| --- | --- | --- |
| Start week on | Any weekday; Monday | Calendar pickers and the “Next week” suggestion. “Later this week” never crosses the chosen week boundary. Weekend suggestions remain Saturday/Sunday. This presentation choice does **not** change shared recurrence calculation boundaries. |
| Date format | System (default), YYYY-MM-DD, DD/MM/YYYY, MM/DD/YYYY | Task-row dates, date-picker buttons/suggestions and inspector file timestamps. System uses the Mac's locale. Exact typed date entry, filters' stored dates, Markdown and CLI formats remain ISO. |
| Time format | System (default), 12-hour, 24-hour | Live Settings preview and Created/Updated file timestamps in the task inspector. Tasks still have date-only scheduled/deadline fields; this adds no task-time schema. |
| Time zone | System when absent, or searchable IANA identifier | **Active vault**, saved to `.config/config.yml`, so app/CLI Today membership and recurrence calculations agree. No vault: control unavailable. |
| Initial view | Today (default), Inbox, Next, Upcoming, Waiting, Someday, All Tasks, Search | Applied on vault opening, including app restoration and switching vaults. Changing it does not navigate away from current work. |
| Badge | Off (default), On | Under **Dock**. Shows the unfiltered Today count for the most recently active vault: incomplete tasks scheduled or due today or earlier, using the vault time zone. Each task counts once; done/canceled tasks are excluded. Hidden at zero or without a vault. |
| Command-line interface | Off until registered | **This Mac**. Automatically registers `/usr/local/bin/taskmark` to the bundled CLI with a native administrator prompt. Disabling removes the link. No vault setting or shell-profile edit. |

`AppPreferences` is an observable projection of the vault's `preferences` mapping. Missing fields use documented defaults; invalid present values are surfaced without rewriting the file. Theme, light/dark mode, week start, date/time formats, startup view and stylesheet enablement are shared, as are sidebar/task ordering and per-view display options. See the [configuration schema](FILE_FORMAT.md#shared-preferences). System appearance/date/time choices still follow each machine's OS/locale; select explicit values for identical rendering.

Preference changes apply immediately and autosave. A save indicator/error banner appears in both Settings and the workspace. Concurrent changes to different top-level fields merge; overlapping changes require **Use File Preferences** or **Keep My Preferences**. Failed writes retain pending edits and block closing or switching vaults until resolved. Copy/sync `.config/` together with the vault's task files to carry preferences to another machine.

### Time-zone safety

The Markdown target owns manifest reads and writes (`VaultStore+Configuration.swift`). It validates schema and IANA identifiers, rejects symlink components and coordinator remaps, compares the entire file's revision, preserves unknown YAML values, and atomically replaces the manifest. Selecting System removes the timezone key. Formatting/comments can normalize. Existing task files and their date values are not rewritten.

Dirty or conflicting drafts must finish saving before changing the time zone. An in-flight timezone save disables workspace editing and blocks vault switching and termination until it finishes. Failures leave the old manifest and selected zone intact, and appear with **Reload Configuration**. Reload before retrying an external-change conflict. Unrelated task undo history, including deletion recovery, survives a successful timezone change.

### CLI registration

Enable **Command-line interface**, approve macOS authorization, then open a new terminal and run `taskmark --help`. The toggle reflects the actual executable symlink, not a saved Boolean. Canceling authorization keeps the previous state; failures are shown in an alert. App updates at the same location automatically update the command. After moving Taskmark, enable it from the new app location to repair the link. Existing unrelated files or links are preserved. App copies running from disk images or App Translocation must be moved to Applications first. See the [CLI guide](../README.md#cli) for custom-shell troubleshooting.

### Dock badge

The Badge preference travels with the vault as `preferences.dock_badge`. It applies immediately and updates when task snapshots, preferences, or the active vault change. The regular vault refresh also reevaluates the vault-local day while the app is running. Search, filters, and the currently selected list do not narrow the count. Closing the active window switches to another open workspace; closing every vault clears the badge.

## Theme

- **System / Light / Dark** controls appearance independently of the chosen palette. System follows macOS. Native controls, sheets, popovers, editors and text use the resolved appearance.
- **Taskmark, Slate, Forest, Sand, Catppuccin, Dracula** each provide paired light/dark palettes. Catppuccin uses Latte in Light and Mocha in Dark; Dracula uses Alucard in Light and Dracula in Dark. Selection applies immediately to sidebar, list, inspector and Settings surfaces and control accents.
- **Apply vault stylesheet** enables `.config/style.css` overrides on top of the selected theme. This preference is saved with the vault. Missing/invalid styles fall back to the selected built-in theme. The Settings section shows parse diagnostics and provides Reveal Vault and Reload Stylesheet actions.

See [THEMES.md](THEMES.md) for every built-in token, custom-theme examples, override precedence and implementation extension points.

## Updates

**Taskmark → Check for Updates…** and **Settings → Updates → Check for Updates…** use Sparkle's native update window to check the latest stable GitHub Release, download a signed update, install it and relaunch. Sparkle shows progress, up-to-date results and connection/verification failures. Checks work without an open vault. Install Taskmark in Applications before updating.

Automatic checking is off by default. Enable **Automatically check for updates** for daily checks while Taskmark is running; downloads and installation remain user-initiated. Sparkle stores this preference and the last-check date locally, outside the vault. System profiling is disabled. GitHub receives the update and download requests.

Development builds without an update verification key disable checking and explain why in Updates. Existing releases without Sparkle require one manual upgrade to the first updater-enabled release. See [release setup](CI_RELEASES.md#sparkle-update-signing) for signing and end-to-end validation.

## Verification

Behavior coverage lives in `AppPreferencesTests`, `WorkspaceSettingsTests`, `CalendarDateFieldTests` and `ConfigurationMutationTests`. The full quality gate is `make check`; it includes the unsigned Debug app build. Settings behavior/build checks do not establish full-window visual correctness.

`SettingsRenderingTests` is an opt-in visual capture utility. It renders isolated native windows with temporary preferences/vaults for both sections and every light/dark palette. On a Mac where the test host can use Screen Recording, set `LOCALTODO_SETTINGS_CAPTURES` to an existing writable directory and run the app test target:

```sh
LOCALTODO_SETTINGS_CAPTURES=/absolute/existing/directory \
  xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp \
  -configuration Debug -destination 'platform=macOS' test \
  -only-testing:LocalTodoAppTests CODE_SIGNING_ALLOWED=NO
```

An offscreen `NSHostingView` bitmap is not full UI evidence because it omits native titlebar and vibrancy layers. Some test-host processes cannot capture their own windows even when the invoking terminal is authorized; the production-workspace capture flow therefore runs `screencapture` from the authorized parent process as documented in [the native screenshot guide](design-exploration/native/README.md). Settings-menu navigation, keyboard/VoiceOver use, active-window sidebar contrast and System appearance switching remain manual acceptance checks.

## Related Guides

- [Themes](THEMES.md): built-in palette values, stylesheet syntax and extension points.
- [Personalization](PERSONALIZATION.md): task/sidebar ordering, context actions and editing interactions.
- [Design](../DESIGN.md): native typography, surfaces, controls and accessibility direction.
- [Roadmap](ROADMAP.md): implemented work and remaining native-window validation.
