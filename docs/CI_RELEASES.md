# Hosted CI And macOS Releases

Taskmark uses GitHub-hosted runners for every workflow. Your Mac does not need to be online or signed into Xcode for CI. Standard hosted runners are used; larger runners are not required.

## Workflows And Trust Boundaries

### Quality — `.github/workflows/quality.yml`

PRs, pushes to `main` and manual runs execute `make check` on `macos-15`, selecting `/Applications/Xcode_26.3.app/Contents/Developer` explicitly. Homebrew supplies SwiftFormat, SwiftLint and XcodeGen. PR Conventional Commit checks run on Ubuntu. Tool versions are printed; the hosted image and Homebrew tools can update, so diagnose tool drift from each run's logs.

Conventional Commit subject format and the 72-character limit apply to ordinary commits. Actual merge commits are exempt in both the optional local `commit-msg` hook and the CI range check, allowing Git-generated messages such as `Merge branch 'develop'`. The range check still validates ordinary commits brought in by merges; writing a merge-like subject on a single-parent commit does not bypass validation. `make check` tests these rules using temporary Git repositories.

The complete gate includes formatting/lint, release-script tests, Swift package tests, macOS app tests and an unsigned Debug app build. Validation receives no signing secrets and only a read-only repository token. PRs use `pull_request`, never privileged execution of contributor code through `pull_request_target`. Validation logs and `.xcresult` files are retained for seven days.

### macOS Release — `.github/workflows/release.yml`

Publishing a release (including a prerelease) starts packaging. Drafts and bare tag pushes do not. A manual dispatch from **main** retries an existing published tag.

1. **Validate:** require a three-part numeric version, an existing published release and a tag whose commit is in `origin/main` history. Resolve the tag to a full SHA once, check out that SHA and run `make check`, without Apple credentials.
2. **Sign:** wait for the `release` environment's owner approval. A fresh hosted Mac checks out the validated SHA, imports environment credentials into a temporary Keychain, archives a universal app/CLI, verifies Developer ID signatures, notarizes/staples the app and DMG, and checks Gatekeeper. Cleanup runs even after failure. Only explicit installer paths and diagnostic logs are uploaded; credential directories are never artifacts or caches. This job has read-only repository access.
3. **Publish:** an Ubuntu job downloads installers from this run, checks hashes and confirms the exact tag still resolves to the validated SHA and the release remains published. It uploads assets using the job-scoped `GITHUB_TOKEN`. Only this job has `contents: write`; it never checks out or executes repository source.

All external actions are pinned to full commit SHAs. Releases have per-tag concurrency; signing is limited to 90 minutes, with each Apple submission waiting up to 30 minutes. Logs are retained for 14 days, intermediate installer artifacts for three days. A timeout requires inspecting Apple's submission status before retrying.

Environment rules apply to the workflow's ref, not the input tag. Manual runs must use `--ref main`; source validation separately checks the requested tag. Environment approval is still necessary: repository build scripts and dependencies executing in an approved signing job can access its credentials. Review the source SHA in the validation summary before approving. Repository administrators and the GitHub/Apple accounts remain trusted.

## One-Time GitHub Setup

Run as the repository owner (`domness`) or a repository administrator:

```sh
gh auth status
gh api repos/domness/taskmark --jq .permissions
python3 scripts/configure-github-actions.py --apply
```

The setup command requires admin access **before making changes**, handles no secrets and is safe to rerun. It configures:

- Environment **`release`**, required reviewer **`domness`**, self-review allowed for solo releases, administrator bypass disabled.
- Selected deployment refs: branch **`main`** and tag pattern **`*.*.*`** (supports both `0.9.0` and `v0.9.0`, including suffixes). The script enforces the stricter numeric version syntax.
- Main ruleset: PR required, both **`swift`** and **`commits`** checks required against an up-to-date branch, discussions resolved, no force-push/deletion and no bypass. Peer approval count is zero so the solo owner can merge; signing has its separate owner gate.
- Tag ruleset: only repository administrators can create, update or delete tags. A write-only agent must ask the owner to create release tags. Do not move a published tag even though the owner technically has bypass permission.
- Read-only default workflow token permissions, with workflow PR approval disabled.
- Fork PR workflow approval for all external contributors, and only GitHub-owned actions pinned to full commit SHAs.

The command manages only its two named rulesets, the `release` environment's protection/ref rules and the Actions policies listed above. It preserves existing environment secrets and unrelated rulesets. A later API failure may leave earlier settings applied; inspect the error and rerun after fixing access.

Review these settings in **Settings → Actions → General** after setup. Approving PR validation does not approve signing. Keep write access limited to trusted collaborators; public readers cannot dispatch the release workflow or publish releases in this repository. The SHA policy intentionally prevents historical workflows using floating action tags from running unchanged.

### Resolving HTTP 403

A token's `repo` scope does not grant repository administration. Check `.permissions.admin` above. For this personal repository, signing into the owner account is the straightforward option:

```sh
# If both accounts are already authenticated:
gh auth switch --user domness
# Otherwise, authenticate the owner interactively:
gh auth login --hostname github.com
```

Never paste a token into an issue, chat or workflow file. An administrative fine-grained token also needs the corresponding repository Administration, Environments and Actions permissions. Use the authenticated owner's CLI or GitHub settings UI for setup.

## One-Time Apple Credentials

Create the protected environment **before adding secrets**. Store all three secrets below in **Settings → Environments → release**, not repository-wide Actions secrets.

| Type | Name | Value |
| --- | --- | --- |
| Secret | `MACOS_CERTIFICATE_P12_BASE64` | Base64-encoded `.p12` containing the Developer ID Application certificate **and private key** |
| Secret | `MACOS_CERTIFICATE_PASSWORD` | Nonempty password used to export that `.p12` |
| Secret | `APP_STORE_CONNECT_PRIVATE_KEY` | Complete PEM contents of the downloaded Apple `.p8` API private key, including header/footer |
| Variable | `APP_STORE_CONNECT_KEY_ID` | Apple API key ID |
| Variable | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID for the App Store Connect **team** API key |

### 1. Export The Signing Identity

On the Mac currently used for releases, open **Keychain Access → login → My Certificates**. Locate and expand:

```text
Developer ID Application: Dominic Wroblewski (4K4TD4WZ4C)
```

Confirm the private key is present underneath it. Export the identity as `.p12` with a strong, nonempty password, to a private directory outside this repository. A downloaded `.cer` alone is insufficient. Do not substitute Apple Development, Apple Distribution or Developer ID Installer.

Upload the file directly from your terminal without displaying its contents:

```sh
base64 -i '/private/path/Taskmark-Developer-ID.p12' | \
  gh secret set MACOS_CERTIFICATE_P12_BASE64 --env release --repo domness/taskmark
gh secret set MACOS_CERTIFICATE_PASSWORD --env release --repo domness/taskmark
```

The second command prompts for the password. Base64 is transport encoding, not encryption; treat the `.p12` and its encoded form as private-key material. Keep any backup in secure storage and remove temporary exports after setup.

The workflow pins team **`4K4TD4WZ4C`** and the identity above. A dedicated CI Developer ID Application certificate under the same team is optional if the account's certificate allowance permits; it enables independent revocation but is still a team signing credential, not scoped just to this repository. There is no unsigned fallback.

### 2. Create A Notarization API Key

In **App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys**, create a dedicated Taskmark CI key for the same Apple team. Use the least role that supports Apple's notarization service (Developer is sufficient for notarization). The account holder may first need to request API access. This workflow expects a **team key with an issuer ID**, not an individual key.

Download the `.p8` once and retain a secure backup. Upload it and its identifiers:

```sh
gh secret set APP_STORE_CONNECT_PRIVATE_KEY --env release --repo domness/taskmark \
  < '/private/path/AuthKey_KEYID.p8'
gh variable set APP_STORE_CONNECT_KEY_ID --env release --repo domness/taskmark --body 'YOUR_KEY_ID'
gh variable set APP_STORE_CONNECT_ISSUER_ID --env release --repo domness/taskmark --body 'YOUR_ISSUER_ID'
```

No Apple account password, interactive Xcode login, personal GitHub token or manually supplied Keychain password is used by the workflow. The Keychain password is generated per job; notary credentials use the fixed `taskmark-ci` profile in `$RUNNER_TEMP/taskmark-signing/signing.keychain-db`.

Existing repository variables `NOTARYTOOL_PROFILE` and `NOTARYTOOL_KEYCHAIN` are no longer read by CI and can be removed. They may still be used as shell environment variables for local packaging.

### 3. Verify Names And Protections

```sh
gh secret list --env release --repo domness/taskmark
gh variable list --env release --repo domness/taskmark
gh api repos/domness/taskmark/environments/release
gh api repos/domness/taskmark/rulesets
```

These list names/settings, not secret values. They cannot prove that the certificate password or Apple credentials are valid; the first approved release verifies import, signing and Apple authentication.

## Migration And First Hosted Release

1. Apply the GitHub protections and upload credentials above.
2. Merge the migration branch through a PR after Quality succeeds on hosted macOS. Do not bypass required checks.
3. Remove **this repository's** personal runner registration/access in **Settings → Actions → Runners**. Older tags still contain the former self-hosted workflow; removing access also prevents those historical workflows reaching your Mac. Do not remove another repository's runner service or certificates.
4. Create a **new version tag** on the merged migration commit or later, then publish its GitHub release as the owner. Historical tags lack the new bootstrap scripts; do not use them to validate the migration or move them to new commits.
5. Wait for validation, review its tag/SHA summary, then approve **Sign and notarize macOS app** through the pending `release` deployment. Approval is also required when an agent initiates the release on your behalf.
6. Verify the workflow and all three assets below. Download the DMG, copy Taskmark to Applications and launch/test it normally. Packaging validation is distinct from downloaded-app interaction.

## Creating Or Retrying A Release

Use the normal release skill, with a new numeric version tag at a full, merged main SHA. Supported examples: `0.9.0`, `v1.0.0`, `v1.0.0-rc.1`. The marketing version strips suffixes; the archive build number is `<workflow run number>.<attempt>`.

The release receives:

| Asset | Purpose |
| --- | --- |
| `Taskmark-<tag>-universal.dmg` | Drag the signed/stapled app into Applications |
| `Taskmark-<tag>-universal.zip` | Complete signed/stapled app bundle, archived with `ditto` |
| `Taskmark-<tag>-SHA256SUMS.txt` | Hashes of the final installers |

Both installers contain a universal macOS 15+ app and the signed universal CLI in `Contents/Helpers/taskmark`. Users register the CLI through **Settings → General → Command-line interface**.

Retry an existing published, post-migration release through **Actions → macOS Release → Run workflow**, selecting **main**, or:

```sh
gh workflow run release.yml --repo domness/taskmark --ref main -f tag=0.9.0
```

Retrying replaces matching filenames (`--clobber`) and changes the build attempt. Use a new tag when downloads must remain immutable. GitHub's workflow `GITHUB_TOKEN` does not trigger downstream release workflows when creating a release; dispatch packaging explicitly in that case.

## Local Validation And Packaging

```sh
make check
make test-release-scripts
bash scripts/package-macos-release --validate-inputs v1.2.3-rc.1 42.1
```

Script tests cover source ancestry/ref checks, input validation and mocked credential setup/failure cleanup. They never use a real signing key or make Apple submissions. `scripts/setup-ci-signing` refuses personal/self-hosted runners, including cleanup; it is not a local setup command.

Local packaging remains available with the pinned identity, a preconfigured notarization profile and an explicit Keychain:

```sh
export APPLE_DEVELOPER_TEAM_ID=4K4TD4WZ4C
export MACOS_SIGNING_IDENTITY='Developer ID Application: Dominic Wroblewski (4K4TD4WZ4C)'
export NOTARYTOOL_PROFILE=local-todo-dominic
export NOTARYTOOL_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
bash scripts/package-macos-release v1.2.3 42.1 dist
```

`dist/` is ignored by Git. Successful local tests/builds do not establish hosted signing or downloaded-app acceptance. The earlier personal-runner pipeline published releases through 0.8.1; the new hosted credential path must be validated with its own approved release.
