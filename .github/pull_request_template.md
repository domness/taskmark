## Summary

<!-- What changed and why? -->

## Validation

- [ ] `make check` passed in full (formatting, lint, release-script checks, package tests, macOS app tests, and the Xcode Debug app build).
- [ ] Confirmed `LocalTodoApp` builds; package-only `swift build` / `swift test` results are insufficient.
- [ ] For Xcode Build/Run fixes, regenerated the project and ran the normal signed clean build below.

```bash
make generate
xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug -destination 'platform=macOS' clean build
```

**Xcode version:** <!-- xcodebuild -version -->

**Commands and results:** <!-- Include any failures, skipped checks with reasons, and reproduction evidence for fixes. -->

**Launch/UI checks:** <!-- Describe what was exercised, or explicitly state not performed. A successful build is not a UI test. -->

## Contract and documentation

- [ ] Added or updated tests for behavior changes, where applicable.
- [ ] Updated relevant documentation and `MEMORY.md` for significant decisions, where applicable.
- [ ] Preserved the vault contract, or documented incompatible changes and migration requirements.
