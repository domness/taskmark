---
name: taskmark-release
description: Bump Taskmark versions across macOS and iOS/iPadOS, or prepare and publish a GitHub release with verified signed and notarized macOS downloads. Use for “bump the version”, “create a new release” or “release Taskmark”; not for managing tasks in a vault.
---

# Release Taskmark

Run commands from the repository root. This skill works as plain Markdown with any coding agent; it requires Git and the repository's macOS build tools, plus the GitHub CLI (`gh`) for publication, not a particular agent harness.

Read the root `AGENTS.md` and its startup guidance, then [the release guide](../../docs/CI_RELEASES.md) and `.github/workflows/release.yml`. Those files remain authoritative for tooling, signing and packaging. Use the existing workflow rather than reproducing signing locally.

Determine whether the request is a version bump only or includes publication. Version changes cover both native apps unless the user explicitly limits them to one platform. A version-only request ends after preparation and validation in section 2, without release notes, tags or publication. The current GitHub workflow distributes only macOS; for an iOS-only publication request, inspect [iOS acceptance](../../docs/IOS_ACCEPTANCE.md) and report the remaining distribution steps rather than invoking macOS packaging as an iOS release.

## 1. Establish the release inputs

- Inspect `git status -sb`, `git remote -v` and recent history. For publication, also inspect `gh auth status`, fetch the remote and tags, and confirm the GitHub repository from the remote; this project currently publishes to `domness/taskmark`.
- For publication, inspect `gh release list`, the latest release's notes/assets, and commits/diff since its tag. Check recent Quality and macOS Release runs with `gh run list`.
- For publication, unless the user specifies another target, release the latest merged `origin/main`. Require a clean checkout synchronized with that target before release versioning. For a version-only request, use the user's intended working branch. Preserve unrelated uncommitted work; do not stash it, include it, reset it or publish an unmerged branch implicitly. Ask when the target is ambiguous.
- Use the user's requested version when supplied. Otherwise infer from the actual unreleased changes and announce the choice: follow the existing three-part `0.x.y` tag style without `v`, increment minor for new features and patch for fixes only. Ask about incompatible changes rather than silently selecting a compatibility policy. For publication, if nothing has changed since the latest release, report that instead of making an empty release.
- For publication, verify the proposed tag and release do not already exist, locally or remotely. Existing versions belong to the retry path below, never a force-updated tag.

## 2. Prepare and validate

1. Inspect both `LocalTodoApp` and `LocalTodoIOSApp` in `project.yml`. Unless the user explicitly requested a platform-only version change, set both targets' `MARKETING_VERSION` to the same numeric version and increment each `CURRENT_PROJECT_VERSION` from its own current value; build numbers need not match. For a prerelease, the marketing version omits the suffix. Follow [both-app versioning](../../docs/CI_RELEASES.md#versioning-both-native-apps); inspect current version sources if the repository has changed rather than inventing version files. The macOS packaging script overrides only its archive versions from the tag and workflow run/attempt.
2. Run `xcodebuild -version` and **`make check`**. All stages must pass, including macOS app tests, shared/mobile and phone/tablet UI tests, and both Debug app builds. Verify both generated app targets' marketing and build versions match the intended changes. Record the commands, toolchain and outcome; do not claim launch, physical-device acceptance or iOS distribution from tests/builds.
3. Inspect status, diff, `git diff --check` and `git log --oneline -10`. Stage only the intended release version file(s). When committing/pushing is authorized, use `chore(build): bump Taskmark to <version>` and push normally to the intended branch. Follow the calling agent's authorization rules; ask for any missing commit/push permission. Never bypass branch protection or hooks. If a PR is required, wait for its merge and validate the resulting target before publication.
4. For a version-only request, report both platforms' resulting marketing/build versions and validation, then stop. For publication, resolve and retain the **full release commit SHA**. Confirm it is on the remote target branch. Do not target a moving branch name when creating the release.

Write concise user-facing notes from the actual changes since the previous tag: improvements/fixes, any real compatibility changes, macOS requirements and installation instructions, validation evidence, and a comparison link. Do not recycle old release highlights or claim artifacts exist before packaging completes. Write notes to a temporary file outside the checkout using the agent's file-writing tool.

## 3. Publish and follow packaging

For a user-authorized stable release, use the inspected values:

```sh
gh release create "$TAG" --repo "$REPO" --target "$RELEASE_SHA" \
  --title "Taskmark $TAG" --latest --notes-file "$NOTES_FILE"
```

This creates the new remote tag at the exact SHA and publishes the release. Tag rules restrict creation to repository administrators; if authenticated as a write-only collaborator, ask the owner to create it rather than bypassing protection. A prerelease uses `--prerelease` instead of `--latest`. Respect a draft-only request: drafts do **not** trigger packaging, so do not describe them as downloadable releases.

Find the new `macOS Release` run with `gh run list --workflow release.yml --repo "$REPO"`; match its tag/event and `headSha` to the release. Watch its ID using `gh run watch "$RUN_ID" --repo "$REPO" --exit-status`. A tool timeout only stops the watcher; inspect/watch the same run again, not a new dispatch.

The published-release event resolves the tag to an exact commit in main history and runs `make check` on hosted macOS. Signing then waits for the owner's `release` environment approval; report the pending run URL and ask the owner to review its source summary. Never approve the signing gate on the owner's behalf. The approved job uses a disposable Keychain, builds a universal macOS 15+ app and bundled CLI, verifies Dominic Wroblewski's pinned Developer ID signature and notarizes/staples. A separate upload-only job publishes the downloads. An empty release page, pending approval or green unrelated Quality run is not completion.

If no run appears, inspect Actions events/permissions and the token used for publication. GitHub's default workflow `GITHUB_TOKEN` does not trigger downstream release workflows. After confirming there is no matching queued/running run, use the documented manual dispatch for the existing published tag:

```sh
gh workflow run release.yml --repo "$REPO" --ref main -f tag="$TAG"
```

## 4. Verify and hand off

Require the matching release workflow to conclude successfully. Inspect `gh release view "$TAG" --repo "$REPO" --json url,isDraft,isPrerelease,assets` and confirm these four nonempty, uploaded assets:

- `Taskmark-<tag>-universal.dmg`
- `Taskmark-<tag>-universal.zip`
- `Taskmark-<tag>-SHA256SUMS.txt`
- `appcast.xml` (its signed enclosure must target this release's ZIP and build)

Check final Git status. Return the release URL, direct DMG link, a brief change summary, both platforms' source marketing/build versions, and validation/packaging outcome. Distinguish signed/notarized macOS packaging from a manual downloaded-app launch and from iOS distribution. Report any remaining local changes explicitly.

## Failed or existing releases

- Inspect the failed job/logs before deciding what to retry. A blocked/offline runner or missing signing credentials is a blocker, not permission to change signing identity, produce unsigned downloads or reset shared Keychains.
- Hosted notarization uses the explicit temporary Keychain from the release guide. Missing credentials require environment setup by the owner. Do not retry implicit credential lookup or expose secrets. Only post-migration tags contain the hosted signing bootstrap; do not retry historical self-hosted workflows or move old tags to migrate them.
- For an authorized packaging retry of unchanged sources, dispatch `release.yml` with the existing published tag after inspecting any prior/active runs and assets. Retries replace matching asset filenames and change the build attempt; use a new version when published downloads must remain immutable.
- Source fixes require a newly validated commit and a new version. Never move/delete a published tag or release without explicit user authorization.
- Do not blindly rerun failures. If progress requires credentials, permissions, a product fix or an unavailable runner, preserve the release/run URL and report the precise blocker. Never report the release as complete until the workflow and assets are verified.
