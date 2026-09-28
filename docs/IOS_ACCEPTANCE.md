# iOS Acceptance Evidence

Status recorded 2026-09-28 for the `codex/ios-app` implementation candidate delivered by pull request #32. The pull request records the exact head commit. This record distinguishes automated, simulator, signed-device and not-run evidence. It does not claim released mobile or iCloud synchronization support.

## Environment

- Xcode 27.0 (build 27A266a) on macOS 27.0 (build 26A428).
- iOS simulator selected by the repository's installed-runtime lookup.
- Physical iPhone 17 Pro Max on iOS 27.0 (build 24A437).
- Taskmark 0.12.0 build 18, bundle identifier `com.domness.localtodo.ios`.
- The physical run used a signed development build. No account identifier, certificate identity or vault content is recorded here.

## Verified Evidence

| Boundary | Result | Evidence |
| --- | --- | --- |
| Shared iOS model/storage behavior | Passed | `make test-ios` executed 147 Domain, Markdown, Workspace, Presentation and mobile-workspace tests with no failures. Fixtures run from the iOS test bundle rather than merely compiling through the app. |
| Phone UI automation | Passed | Six XCTest UI scenarios passed: compact/adaptive navigation, capture, task detail actions, onboarding, broad workflow coverage and the incomplete-vault navigation-title regression. |
| Full repository quality gate | Passed locally | `make check` passed for the final working tree on Xcode 27.0, including Mac/CLI tests, native app tests, the expanded iOS test run and both app builds. GitHub checks remain the remote evidence for the pull-request head. |
| Signed device build/install | Passed | The final source built for and installed on the named physical iPhone using automatic development signing. Its immediate launch retry was denied only because the phone had locked. The preceding branch head had launched successfully on the same device. |
| Existing iCloud vault restoration | Passed as a smoke test on the preceding branch head | The app restored the previously selected vault after launch, displayed Today with the navigation header intact, materialized a complete snapshot and did not retain the “Vault data is incomplete” banner. The subsequent foreground-polling addition has automated coverage and does not change vault parsing or presentation. |
| Foreground provider observation | Passed in automated coverage | A regression test verifies that file presentation and polling start for an active restored vault and stop when observation is suspended. |
| Generic Release archive | Passed | A development-signed generic iOS archive was created and passed strict signature verification. The archived app contains the expected bundle ID/version, phone/tablet icons, fonts, font licenses and third-party notices. App Store distribution signing/export was not exercised. |

The device smoke test establishes the concrete reported failure is no longer reproduced on that device. It does not establish bidirectional delivery, conflict recovery or the complete physical-device sequence below.

## Automated Matrix Status

| IDs | Status | Notes |
| --- | --- | --- |
| A01–A10 | Covered in part by shared tests | File-format preservation, initialization safety, partial availability, coordination failures, drafts, recurrence, filters, preferences and recovery have automated coverage. Provider-specific physical behavior remains subject to the manual sequence. |
| A11–A12 | Covered in part by app/UI tests | Themes, navigation and primary workflows are automated on a phone simulator. Full appearance, iPad, assistive-technology and hardware-keyboard coverage is not complete. |
| A13 | Passed for the available current simulator | The shared iOS tests, phone UI tests and Mac/CLI gate pass. Minimum-iOS and tablet destinations remain not run. |

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

- Development-signed installation and launch: **passed**.
- Generic iOS development-signed archive and resource validation: **passed**.
- App Store distribution signing and TestFlight export validation: **not run**.
- TestFlight export/upload: **not run and not authorized by this implementation task**.
- Public App Store release: **out of scope and separately authorized**.

Any failed data-preservation or recovery case blocks release. Simulator success and the physical smoke test do not replace this matrix.
