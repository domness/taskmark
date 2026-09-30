# iOS Acceptance Evidence

Status recorded 2026-09-28 for the `codex/ios-app` implementation candidate delivered by pull request #32. The pull request records the exact head commit. This record distinguishes automated, simulator, signed-device and not-run evidence. It does not claim released mobile or iCloud synchronization support.

## Environment

- Xcode 27.0 (build 27A266a) on macOS 27.0 (build 26A428).
- iPhone 16 Pro and iPad Pro 11-inch (M4) simulators on iOS/iPadOS 18.4 for the repository gate.
- iPhone 18 Pro and iPad Pro 13-inch (M5) simulators on iOS/iPadOS 27.0 for current-runtime UI checks.
- Physical iPhone 17 Pro Max on iOS 27.0 (build 24A437).
- Taskmark 0.12.0 build 18, bundle identifier `com.domness.localtodo.ios` (historical evidence; the current source now configures `com.tinycorestudios.taskmark` for the next build).
- The physical run used a signed development build. No account identifier, certificate identity or vault content is recorded here.

## Verified Evidence

| Boundary | Result | Evidence |
| --- | --- | --- |
| Shared iOS model/storage behavior | Passed | `make test-ios` executed 147 Domain, Markdown, Workspace, Presentation and mobile-workspace tests with no failures. Fixtures run from the iOS test bundle rather than merely compiling through the app. |
| Phone and tablet UI automation | Passed | Six compact-phone XCTest UI scenarios cover navigation, capture, task detail actions, onboarding, broad workflows and the incomplete-vault navigation-title regression. A separate iPad scenario verifies the initial three-column Today workspace and task-detail selection. |
| Full repository quality gate | Passed locally | `make check` passed for the final working tree on Xcode 27.0, including Mac/CLI tests, native app tests, the expanded iOS test run and both app builds. GitHub checks remain the remote evidence for the pull-request head. |
| Signed device build/install | Passed | The final source built for, installed on and launched on the named physical iPhone using automatic development signing. A device screenshot records the final head running with the Today navigation header visible and no incomplete-vault banner. |
| Existing iCloud vault restoration | Passed as a smoke test | The app restored the previously selected vault, displayed Today with the navigation header intact, materialized a complete snapshot and did not retain the “Vault data is incomplete” banner. The final head also launched without the banner after reinstalling over that device state. |
| Foreground provider observation | Passed in automated coverage | A regression test verifies that file presentation and polling start for an active restored vault and stop when observation is suspended. |
| Generic Release archive | Passed | A development-signed generic iOS archive was created and passed strict signature verification. The archived app contains the expected bundle ID/version, phone/tablet icons, fonts, font licenses and third-party notices. App Store distribution signing/export was not exercised. |

The device smoke test establishes the concrete reported failure is no longer reproduced on that device. It does not establish bidirectional delivery, conflict recovery or the complete physical-device sequence below.

## Automated Matrix Status

| IDs | Status | Notes |
| --- | --- | --- |
| A01–A10 | Covered in part by shared tests | File-format preservation, initialization safety, partial availability, coordination failures, drafts, recurrence, filters, preferences and recovery have automated coverage. Provider-specific physical behavior remains subject to the manual sequence. |
| A11–A12 | Covered in part by app/UI tests | Themes, compact navigation and primary workflows are automated on a phone simulator; the initial adaptive sidebar/list/detail workflow is automated on iPad. Full appearance, multitasking, assistive-technology and hardware-keyboard coverage is not complete. |
| A13 | Passed for configured phone and tablet simulators | The shared iOS tests, phone and tablet UI tests, and Mac/CLI gate pass on the iOS 18.4 destinations. The full phone UI suite and adaptive tablet scenario also pass on iOS/iPadOS 27.0. |

## Required Physical Sequence

The seven-step sequence in [IOS_SPEC.md](IOS_SPEC.md#required-physical-device-interoperability-run) is not complete and remains release-blocking:

1. Mac-created disposable vault opened on both iPhone and iPad: **not run** beyond opening an existing vault on one iPhone.
2. Bidirectional create/edit/complete/repeat/checklist operations with exact CLI/on-disk verification: **not run**.
3. Bidirectional themes, timezone, view options, ordering, filters and external stylesheet reload: **not run**.
4. Offline edits, reconnection, non-overlapping/overlapping changes and explicit provider-version recovery: **not run**.
5. Remove Download, unavailable manifest, poor connectivity, signed-out iCloud, read-only and revoked access: **not run** beyond successful materialization of the reported incomplete vault.
6. Background/termination checkpoint recovery, single recurrence advancement and externally moved vault recovery: **not run**.
7. iPhone orientation, iPad multitasking, hardware keyboard, VoiceOver, accessibility sizes and appearance/contrast combinations: **not run**.

## Distribution Status

- Current source bundle identifier for the next archive/TestFlight build: `com.tinycorestudios.taskmark`.
- Development-signed installation and launch: **passed**.
- Generic iOS development-signed archive and resource validation: **passed**.
- App Store distribution signing and TestFlight export validation: **not run**.
- TestFlight export/upload: **not run and not authorized by this implementation task**.
- Public App Store release: **out of scope and separately authorized**.

Any failed data-preservation or recovery case blocks release. Simulator success and the physical smoke test do not replace this matrix.
