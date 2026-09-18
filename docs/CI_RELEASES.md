# Mac Mini CI And macOS Releases

## Workflows

### Quality — `.github/workflows/quality.yml`

- Pushes to `main` and manual runs use `[self-hosted, macOS]`, matching Lumelo (`domness/baby-journal`). The Mac Mini must be registered/available to **this repository**, not only Lumelo.
- Pull requests keep GitHub-hosted `macos-15` validation and Ubuntu Conventional Commit checks. PR code does not execute on the personal signing runner.
- The Swift job runs the actual `make check`: formatter, strict lint, release-script input/syntax tests, Swift package tests, macOS app tests, and unsigned Debug app build.
- Each run has isolated DerivedData under `RUNNER_TEMP`, uploads its log and `.xcresult`, and removes only its own temporary build directory. It does not kill Xcode processes or purge another project's caches/keychains. Quality logs are retained for seven days.
- Per-ref concurrency avoids overlapping validation for the same branch without interrupting an active run. GitHub may replace older pending runs with a newer pending commit.

### macOS Release — `.github/workflows/release.yml`

Publishing a GitHub release (including a prerelease) checks out **that exact tag**, runs `make check`, then builds a Release archive for Apple Silicon and Intel (`arm64` + `x86_64`, macOS 15+). Draft releases and bare tag pushes do not package automatically. Tags must contain a three-part numeric version, such as `v1.0.0`, `1.0.0`, or `v1.0.0-rc.1`.

Release signing is pinned to Dominic Wroblewski:

```text
Apple team:        4K4TD4WZ4C
Signing identity:  Developer ID Application: Dominic Wroblewski (4K4TD4WZ4C)
Notary profile:    local-todo-dominic
```

The team matches Lumelo's project and the available Dominic Wroblewski distribution identities. The workflow uses manual identity selection, enables hardened runtime and secure timestamps, verifies the resulting Developer ID certificate/team requirement, notarizes and staples the app, and packages it. It then signs, notarizes and staples the DMG too. Both distribution paths include the stapled `.app`. Missing credentials, signing, architecture, notarization, stapling, or Gatekeeper-assessment failures stop publishing; there is **no unsigned fallback**.

The release receives:

| Asset | Purpose |
| --- | --- |
| `Taskmark-<tag>-universal.dmg` | Open the disk image and drag **Taskmark.app** to **Applications**. |
| `Taskmark-<tag>-universal.zip` | An alternative archive containing the complete stapled **Taskmark.app** bundle. Extract it, then move the app to Applications. |
| `Taskmark-<tag>-SHA256SUMS.txt` | SHA-256 checksums of the final ZIP and DMG. |

GitHub release assets are files, so the `.app` directory is shipped inside the ZIP/DMG rather than uploaded as a loose folder. ZIP creation uses `ditto` to preserve bundle metadata. Version `v1.2.3-rc.1` produces `CFBundleShortVersionString=1.2.3`; the full tag remains in artifact filenames. Build version is the workflow run number plus attempt, e.g. `42.1`. The supported build-number range is 1–9999 with optional two-digit minor/patch components.

Failed runs retain packaging logs/notary JSON and test results as Actions artifacts for 14 days. Apple submission details can be inspected with `xcrun notarytool log <submission-id> --keychain-profile local-todo-dominic` on the runner. Release jobs have a 90-minute timeout; each notarization submission waits at most 30 minutes. A notarization timeout may require checking Apple's final status and rerunning the workflow.

## One-Time Mac Mini Setup

Run setup as the **same macOS user running the GitHub runner**, signed into Dominic's Apple account in Xcode. Existing Xcode account sign-in alone does not provide a Developer ID Application private key or `notarytool` credentials.

### 1. Runner And Tools

1. As a GitHub repository admin, open `domness/local-todo` → **Settings → Actions → Runners**. Register a macOS runner on the Mini using GitHub's displayed commands, or grant this repo access to an existing organization runner. Use a separate runner installation directory if adding another repo-specific service; a Lumelo-only registration cannot receive this repo's jobs.
2. Keep labels `self-hosted` and `macOS`. If more than one machine has those labels and only the Mini should run these jobs, add a Mini-specific label and include it in both workflows.
3. Run in the logged-in user session so hosted macOS app tests and keychain access work. Keep the runner awake and online. Avoid concurrent runner services running Lumelo cleanup that kills all Xcode processes; these workflows themselves clean only their own temporary paths.
4. Select the full Xcode installation and complete its first-launch/license setup. Use Swift 6 and a macOS 15+ SDK. CI prints selected tool versions for diagnosis.
5. Install the command-line prerequisites once:

```sh
brew install xcodegen swiftformat swiftlint gh python
bash scripts/check-macos-runner
```

Self-hosted jobs verify installed tools; they do not upgrade Homebrew or change global Xcode selection. Hosted PR jobs install quality tools automatically. Use the same formatter/linter versions as local development when investigating formatting drift (implementation validation used SwiftFormat 0.63.0, SwiftLint 0.65.1, XcodeGen 2.46.0, Xcode 27.0).

### 2. Dominic's Developer ID Certificate

In **Xcode → Settings → Accounts → Dominic Wroblewski → Manage Certificates**, create/download **Developer ID Application** for team **4K4TD4WZ4C**, or import the existing certificate **and private key** into the runner user's login keychain. Do not substitute Apple Development, Apple Distribution, or Developer ID Installer. The latter is for `.pkg` installers, which this workflow does not produce.

Confirm the exact identity is available:

```sh
security find-identity -v -p codesigning
```

Ensure the runner can use this private key non-interactively: unlock the login keychain for its session and authorize the standard Apple signing tools when prompted. The workflow intentionally does not delete/reset keychains, install certificates, or alter global signing access.

### 3. Notarization Credentials For The Same Account/Team

Create an app-specific password for Dominic's Apple account and store it in the runner's keychain (the tool prompts securely for the password):

```sh
xcrun notarytool store-credentials local-todo-dominic \
  --apple-id '<Dominic Apple account email>' \
  --team-id 4K4TD4WZ4C
```

Use Dominic's actual Apple account email; it is not inferred from the certificate display name. An App Store Connect API key for the same team can alternatively be stored with `notarytool store-credentials`; the workflow still consumes only the profile name.

The default profile name is `local-todo-dominic`. If an existing same-team profile has a different name, set repository **Actions variable** `NOTARYTOOL_PROFILE` to that name. Certificate/team values are explicitly pinned in workflow source and also checked by the preflight script. No Apple password or private key is stored in the repository or workflow logs, and no GitHub signing secrets are required with this keychain-based setup.

GitHub's job-scoped `GITHUB_TOKEN` supplies release upload permission. The `gh` upload step uses it through `GH_TOKEN`; a personal token does not need to be installed on the runner.

## Creating Or Retrying A Release

The workflows are in `main`. After completing the runner/signing setup above:

1. Create a tag containing the release workflow/scripts, e.g. `v1.0.0`, at the intended commit.
2. Publish a GitHub release for that tag. Wait for **macOS Release** to finish; assets appear only after packaging/verification succeeds.
3. Download the DMG, copy the app to Applications, and open it normally.

Use **Actions → macOS Release → Run workflow**, entering an existing published release tag, to retry packaging without republishing the release. Reruns replace matching asset filenames (`--clobber`), and increment the build attempt. Use a new version tag rather than rerunning if you need immutable public downloads.

If release creation is later automated by another workflow, GitHub's default `GITHUB_TOKEN` does not trigger downstream release workflows. In that case dispatch **macOS Release** explicitly or use an appropriately scoped GitHub App token for release creation.

## Local Commands And Verification Boundaries

```sh
make check
make test-release-scripts
bash scripts/package-macos-release --validate-inputs v1.2.3-rc.1 42.1

export APPLE_DEVELOPER_TEAM_ID=4K4TD4WZ4C
export MACOS_SIGNING_IDENTITY='Developer ID Application: Dominic Wroblewski (4K4TD4WZ4C)'
export NOTARYTOOL_PROFILE=local-todo-dominic
bash scripts/package-macos-release v1.2.3 42.1 dist
```

`--validate-inputs` only validates/maps version strings; it does not build, sign, or publish. The normal packaging command always requires the pinned identity and notarization profile. `dist/` is ignored by Git.

Initial local validation on 2026-09-17 used Xcode 27.0 (`27A266a`): actionlint 1.7.7, Bash syntax/input-contract checks, and an unsigned universal Release archive with both architecture slices and correct `1.2.3`/`42.1` plist versions. The full `make check` also passed with the workflow's isolated DerivedData and `.xcresult` arguments. Use current Actions results and test output for subsequent runs rather than a fixed test count.

That archive check established compilation/layout, **not signing or notarization**. At initial setup, the implementation machine lacked the Developer ID identity and the connected GitHub account lacked repository-admin permission, so runner registration and end-to-end signed publication were not verified. No release was created or uploaded during that validation. Confirm the runner's present credentials and inspect a successful release run plus a downloaded-app launch before treating distribution as validated.
