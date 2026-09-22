# Security Policy

## Supported Versions

Security fixes target the latest published Taskmark release and the current `main` branch. Older releases may not receive backports.

## Reporting A Vulnerability

Do not publish vulnerability details in a public issue. Open a minimal issue titled **Security contact request** containing no technical details or personal data. A maintainer will arrange a private channel for the report.

In the private report, include the affected version, impact, reproduction steps, and any suggested mitigation. Avoid including real vault contents, credentials, signing material, or other personal data. You should receive an initial response within seven days.

Taskmark operates on user-owned files and invokes privileged macOS authorization only when enabling or disabling the optional `/usr/local/bin/taskmark` link. Reports involving file preservation, path traversal, symlink handling, command registration, release signatures, or notarization are especially useful.

## Public Disclosure

Please allow time to investigate and prepare a fix before publishing details. Confirmed issues will be documented with the release that resolves them.
