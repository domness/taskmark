# Reusable Engineering Lessons

Read this file before repeating an approach that previously required several attempts. Keep entries general, current, and free of incident chronology or environment-specific personal data.

## Filesystem Transactions

- **Failure pattern:** Check-then-write creation, recursive rollback, sequential multi-file replacement, or suppressed rollback errors can overwrite concurrent work or leave a mixed vault state.
- **Reliable approach:** Validate immediately before publication, use exclusive atomic creation/rename, use non-recursive cleanup, coordinate exact source/destination paths, and disable operations whose all-or-nothing contract cannot be met.
- **Next-time rule:** Review every cleanup and conflict path as part of the transaction; add injected-failure and concurrent-change tests before enabling a mutation.

## Drafts, Autosave, And History

- **Failure pattern:** View-owned drafts, independent refresh/save work, or history registration before persistence cause lost edits, stale publication, invalid Undo state, and retries that repeat calculated transitions.
- **Reliable approach:** Keep drafts in the workspace model, serialize per-path mutations, reject stale sessions/epochs, merge successful writes immediately, reserve history paths before async work, and register field-specific Undo only after persistence.
- **Next-time rule:** Model asynchronous UI mutations as state machines and test delayed writes, overlapping edits, navigation, close/quit, Undo/Redo, and semantic conflict dependencies.

## YAML Preservation

- **Failure pattern:** Replacing whole nested mappings loses unknown metadata; assigning `nil` through a generic Yams `Node` does not remove a key.
- **Reliable approach:** Mutate `Node.Mapping`, preserve unknown sibling values, and test serialized output after both setting and clearing optional fields.
- **Next-time rule:** Verify a save-reload cycle and exact preservation behavior whenever a schema mutation changes optional or nested YAML.

## Native SwiftUI Tests

- **Failure pattern:** Fixed sleeps, cached AppKit controls, assumed key-window activation, bare hosting views, and direct low-level event calls produce toolchain-dependent focus, toolbar, keyboard, and resize failures. In-process SwiftUI accessibility trees may omit rendered elements and identifiers when no accessibility client is attached. Inspector animations can stall in occluded/locked sessions even after toolbar labels update.
- **Reliable approach:** Host through the real view-controller/scene boundary, locate current native controls after transitions, post keyboard events through the application queue, and use bounded predicates for responders, selection, editor lifetime, toolbar labels, mutation results, and window constraints. Disable animations in final-geometry tests and wait for both panel presentation and stable toolbar frames.
- **Next-time rule:** Test readiness rather than elapsed time, run focused tests inside the complete app suite, and keep physical gesture/VoiceOver acceptance distinct from hosted integration evidence. Exercise native buttons in focused hosts rather than relying on an inactive accessibility tree to locate SwiftUI actions.

## Native Toolbar Sizing

- **Failure pattern:** Forcing SwiftUI label/outer frames and borderless styles into a native toolbar distorts symbol placement and material sizing. Replacing NavigationSplitView's sidebar toggle can leave a duplicate control. SwiftUI Spacer becomes a flexible native toolbar item regardless of its frame; custom toolbar items can retain a stale minimum width after their contents shrink. Moving an inspector outside navigation can reintroduce small-window split overflow or constraint loops.
- **Reliable approach:** Use the full-size unified toolbar with standard buttons/menus and the automatic sidebar toggle. Keep the inspector in the detail column and reserve its measured width with an inert native space. Give that space width-dependent identity to refresh NSToolbar's cached minimum; keep interactive controls stable.
- **Next-time rule:** Test real scene geometry against the actual panel boundary, including inspector shrink/grow, repeated open/close, narrow windows and duplicate controls. Compare full-size and compact controls on the running OS instead of assuming newer-system dimensions on older supported macOS versions. Inspect a complete window when capture is available; minimum-size assertions alone do not establish correct visual presentation.

## Test Resource Lifetime

- **Failure pattern:** A closed test window can retain a workspace whose refresh work continues against a deleted fixture, surfacing unrelated alerts and breaking later focus tests.
- **Reliable approach:** Explicitly release workspace/window resources before deleting fixture vaults on both success and failure paths.
- **Next-time rule:** When a later native test fails unexpectedly, inspect retained async work and modal state before changing product focus behavior.

## Native Window Capture

- **Failure pattern:** Offscreen bitmaps omit titlebar/vibrancy layers, while a test-host child may lack capture permission even when the invoking development tool is authorized. A locked desktop can reject window capture despite granted Screen Recording access.
- **Reliable approach:** Keep the production native test window visible, emit its WindowServer ID, and run `screencapture` from the authorized parent process. Treat inactive-window styling and physical interaction as separate evidence.
- **Next-time rule:** Check Screen Recording permission and desktop availability before capture. If the session is locked, label any offscreen fallback as content-only layout evidence, never full-window visual acceptance.

## Native Dragging And Inline Editing

- **Failure pattern:** Row-wide buttons and competing gestures consume native list drag tracking; synthetic mouse sequences cannot reliably complete WindowServer drag sessions in a background host.
- **Reliable approach:** Let the native List own selection/insertion, use one full-row task payload for supported destinations, and verify deterministic payload/selection/model behavior separately from a physical drag check. Use the real native editor lifecycle for inline text tests.
- **Next-time rule:** Do not infer gesture correctness from model tests alone, and do not treat limitations of synthetic background events as product defects.

## Packaging And Tooling

- **Failure pattern:** Products differing only by case collide on common macOS filesystems; implicit notarization credential lookup and assumed command forms can vary by toolchain; successful builds do not prove bundled resources or signatures.
- **Reliable approach:** Keep the CLI in `Contents/Helpers`, select the notarization Keychain explicitly, inspect real archive architectures/resources/signatures, and validate downloaded artifacts separately.
- **Next-time rule:** Test packaging commands against an actual universal archive and verify runtime resource resolution, signing, notarization, stapling, and checksums as distinct stages.

## Formatting And Validation Tools

- **Failure pattern:** Formatter/linter edge cases around long predicates, embedded shell strings, and broad rule suppression lead to repeated gate failures; skill validators may require undeclared Python packages.
- **Reliable approach:** Extract named validation functions, account for indentation in line limits, use narrow documented exemptions, and run validators in an isolated temporary environment with their required dependencies.
- **Next-time rule:** Prefer clearer structure over tool suppression and check validator prerequisites before debugging content.
