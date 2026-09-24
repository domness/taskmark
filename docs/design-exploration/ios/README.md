# Taskmark Mobile Screen Concepts

**[Open the concept image gallery →](GALLERY.md)**

Design exploration for [the iOS spec](../../IOS_SPEC.md), using synthetic task content. These are rendered HTML/CSS mockups exported as PNGs, not screenshots of a working iOS app. Native controls, gestures, Dynamic Type and accessibility still need implementation and device validation.

## Direction contract

**Mode / thesis:** Operate. Bring the established focused canvas to touch: a readable task list and progressive organization, rather than a miniature desktop inspector or a productivity dashboard.

**Own-world:** Existing Taskmark light surfaces and blue control tint; Catppuccin Mocha for the dark personalization example. Native system typography, Figtree for Catppuccin, restrained separators and real SF Symbols.

**Story:** Open Today, read a task, capture another, find collections, and personalize the same vault. A separate status concept makes local persistence and provider availability understandable.

**First viewport:** Large native-style titles, 24-point content margins, title-first task rows, top-right capture and bottom Today/Inbox/Browse/Search navigation. Details use notes above two compact property sections. iPad uses sidebar/list/detail.

**Form:** Direct translation of the already specified mobile structure and established Taskmark design, confirmed with the user; no new identity or concept selection seed. iOS 18-style tab/navigation bars are shown, not a prediction of newer OS-owned glass rendering.

**Finish:** All ten PNGs received independent visual review; the single layout finding was corrected and rechecked as resolved. See verification below. These images establish design intent, not native UI acceptance.

## Screens

- `today`: grouped daily work, light Taskmark palette.
- `detail`: rendered task notes, checklist, Planning and Organization.
- `capture`: title-first capture sheet and illustrative system keyboard.
- `browse`: built-in views, projects, areas, tags and saved filters.
- `themes`: all six palettes and shared stylesheet enablement.
- `today-dark`: the same Today content in Catppuccin Mocha.
- `vault`: partial availability and provider conflict state.
- `ipad`: adaptive three-column workspace.

## Verification and evidence

- **Exports:** Seven individual iPhone PNGs at 786×1704 pixels (2× a 393×852-point composition), plus three overview boards: daily workflows, personalization and iPad workspace. The existing Taskmark palette and typography direction are preserved; this exploration introduces no new design-system decision.
- **Rendering:** Chromium via local Playwright produced the PNGs because the desktop browser integrations were disconnected. Browser JavaScript syntax and font/icon loading were checked; SF Symbols were rasterized locally with `export-symbols.swift`.
- **Visual review:** An independent reviewer inspected all ten PNGs. The only finding, the iPad footer's bottom safe-area spacing, was corrected and rechecked as resolved, with a measured 27.86-point bottom inset in the concept. Reviewer disposition: **ship the concept set**, not native UI acceptance.
- **Repository quality gate:** `make check` passed on Xcode 27.0 (build 27A266a), including lint, 130 package tests, 165 macOS app tests and the macOS Debug build. This validates the existing repository, not an implemented iOS client.
- **Acceptance boundary:** Static concepts do not establish exact native hit targets, VoiceOver behavior, Dynamic Type adaptation or gestures. Those require native implementation and device validation.

## Reproduce

From the repository root:

```sh
swift docs/design-exploration/ios/export-symbols.swift
python3 -m http.server 8783 --bind 127.0.0.1
```

Open `/docs/design-exploration/ios/index.html?board=daily`, `?board=personalization`, or `?board=ipad`. Use `?screen=today` (or another phone screen name) for a 2× 786×1704 export. Append `&export=1` to hide review navigation, then capture the `#artboard` element. The HTML is a static composition, not an interactive app prototype.

## Provenance

- Layout/text: authored mockup HTML/CSS/JavaScript in this directory, based on `DESIGN.md` and `docs/IOS_SPEC.md`.
- Icons: Apple SF Symbols rasterized locally by `export-symbols.swift`, used to illustrate the proposed Apple-platform interface.
- Brand icon: existing Taskmark app icon resource.
- Fonts: existing bundled Figtree/Inter assets and their licenses; system typography otherwise.
- PNG exports: browser-rendered from these source files, no image-generation API or model used.
- Embedded PNG comments record the source files, render date (2026-09-24), synthetic concept status, Apple SF Symbols, existing Taskmark icon/font assets and absence of AI image generation. They document asset provenance; the verification and review results are recorded above.

Keep these compositions as reference material. The file contract and iOS specification govern behavior if an illustrative detail is ambiguous.
