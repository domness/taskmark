# Onboarding design QA

Reviewed 13 October 2026 against the approved option 1 revision, with the
“A calmer place…” subtitle removed.

## Reference and captures

The Mac and iPhone screenshots are committed for PR review. Other paths below
are local review artifacts excluded from source control by the `.build` rule.

| Artifact | Path | Size and state |
| --- | --- | --- |
| Approved reference | `.build/onboarding/approved.png` | 1589 × 990; Mac dark and iPhone light concept |
| Mac implementation | `docs/design-exploration/onboarding/mac.png` | 1120 × 720; active welcome window, dark appearance |
| iPhone implementation | `docs/design-exploration/onboarding/iphone.png` | 1206 × 2622; iPhone 18 Pro, light appearance |
| iPad implementation | `.build/onboarding/tablet/D4A8D98C-7EDC-48CA-A7F6-7A1F2AD724C0.png` | 2064 × 2752; iPad Pro 13-inch, light appearance |
| Accessibility text | `.build/onboarding/phone/82AB6B79-B534-4F25-945B-0B9E98301498.png` | 1206 × 2622; largest accessibility text, top |
| Accessibility actions | `.build/onboarding/phone/BCD54F2C-A53C-4C75-8FEA-9E55D7B2D2DE.png` | 1206 × 2622; largest accessibility text, scrolled |

## Comparison and corrections

The approved reference and implementation captures were inspected together.
The implementation retains the real Taskmark icon, approved heading and copy,
prominent sample action, divider, secondary create/open actions and explanatory
footer. Mac secondary actions sit side by side; iOS actions stack. The iPad
composition remains centered with a bounded content width.

The first Mac capture exposed a missing packaged image; moving the icon into a
processed asset catalog fixed it. Subsequent captures informed the final type
sizes and eight-point button corners. The primary button uses the darker
standard accent in both appearances to keep its white label legible.

Native backgrounds and controls replace the concept image's rendering effects.
The iPhone helper wraps naturally at the actual device width. At the largest
accessibility text size, labels wrap and all actions and footer content remain
reachable by scrolling. No unresolved clipping or missing-content issue was
observed in these captures.

## Functional and build evidence

Validation used Xcode 27.0 (27A266a), iOS 27 simulators and the local Mac.

- Sample storage tests pass, including injected write/publish failures,
  concurrent creation, relative dates and preservation of later user changes.
- New Mac workspace and mobile workspace sample tests pass.
- The full iPhone shared/mobile and UI suite passes. Final focused phone tests
  cover opening the sample, adding a task, restoring it after relaunch, welcome
  actions and the largest accessibility text size.
- Tablet sample and adaptive workspace UI checks pass.
- `make build` and a clean iOS Simulator build pass. These are unsigned build
  checks; launch/UI evidence is recorded separately above.
- Manual Mac checks confirm sample opening and persistence, plus the native
  create-vault chooser and cancellation.

The complete `make check IOS_SIMULATOR_NAME='iPhone 18 Pro'` gate is not green:
four existing checkpoint tests cannot read protected files on this Mac
(NSCocoaErrorDomain 257 / POSIX EPERM). A standalone Foundation reproduction
also fails to read newly written protected files, while ordinary atomic files
remain readable. File protection was not weakened.

Separately, the Mac suite has three existing inspector toolbar position
assertion failures. The same assertions fail with the same 76-point measured
gap when testing an exported, unchanged `HEAD` checkout. These are outside the
onboarding change.

Command logs are under `/tmp/taskmark-onboarding-final-check.log`,
`/tmp/taskmark-onboarding-mac-tests.log`,
`/tmp/taskmark-baseline-toolbar-test.log`,
`/tmp/taskmark-ios-phone-tests.log`,
`/tmp/taskmark-ios-final-onboarding-tests.log` and
`/tmp/taskmark-ios-final-tablet-tests.log`.

## Scope limits

Visual approval here covers the captured welcome layouts and sample entry
flow. It does not certify the full release gate, real-device file-provider
behavior, VoiceOver traversal or App Review acceptance. No submission or
release was performed.

## Final visual result

passed
