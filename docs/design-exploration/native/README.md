# Native focused canvas

These are full WindowServer captures of the production SwiftUI workspace with an isolated example vault, on macOS 27.0 (26A428), Xcode 27.0 (27A266a). They are not browser mockups or offscreen view bitmaps. The hosted test window is inactive, so the titlebar/sidebar show native inactive styling.

| State | Screenshot |
| --- | --- |
| Today, light, grouped by project | [Focused canvas](focused-canvas.png) |
| Explicitly opened notes-first inspector | [Inspector](notes-inspector.png) |
| Today, dark | [Dark canvas](focused-canvas-dark.png) |
| Project title and notes | [Project canvas](project-canvas.png) |

Reproduce after `make generate`:

```sh
python3 scripts/capture-native-canvas.py docs/design-exploration/native
```

The process hosting that command needs Screen Recording permission. No audio permission is needed. The opt-in fixture does not touch the user's vault or preferences. Full physical drag, VoiceOver, all-palette contrast, active-window appearance and macOS 15 runtime acceptance remain separate from these images and the automated build/tests.
