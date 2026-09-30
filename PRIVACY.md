# Taskmark Privacy Policy

Last updated: 30 September 2026

This policy covers the Taskmark apps for macOS, iPhone and iPad, and the bundled `taskmark` command-line tool. Taskmark is developed by Tiny Core Studios ("we", "us").

Taskmark works with files you control. It does not require a Taskmark account, and we do not receive your tasks or vault contents through normal use of the app.

## Your tasks and files

Taskmark reads and writes the vault folder you select to provide task capture, planning, search and editing. Your tasks, notes, projects, areas, tags and dates are stored as Markdown files. Vault settings, saved filters and optional appearance files are stored alongside them in the vault's `.config` folder.

This information is processed on your device. Taskmark does not upload it to a server operated by us. The command-line tool uses the same files and does not send command input or output to us.

## Information stored on your device

Taskmark stores information needed to reopen your selected folder and remember device-specific settings, such as folder access bookmarks, macOS window settings and update preferences. The iPhone and iPad app also stores recovery copies of unfinished edits in its local app storage so you can recover unsaved work after an interruption. These copies may contain task titles, notes and other information you entered.

Taskmark does not send these settings or recovery copies to us. Your operating system or backup provider may include local app data in backups according to your device and account settings.

## iCloud Drive and other file providers

You may choose a vault in iCloud Drive or another supported file provider. In that case, the provider handles storage and synchronization under its own terms, privacy policy and your account settings. Taskmark accesses the folder through operating-system file APIs; we do not operate a Taskmark sync service or receive a copy of your vault.

For iCloud, see [Apple's Privacy Policy](https://www.apple.com/legal/privacy/). For another provider, consult that provider's policy. Choosing a local folder avoids using a cloud file provider for that vault.

## Analytics, advertising and tracking

Taskmark does not include advertising, behavioral analytics, third-party tracking or an app-operated crash-reporting service. We do not sell your personal information or use your task content for advertising. Taskmark does not request access to your contacts, photos, microphone or location to provide its task-management features.

Apple may process App Store transactions and diagnostic information under its own policies and your settings. This is separate from Taskmark's local processing.

## macOS update checks

The directly distributed macOS app uses Sparkle to check for updates hosted on GitHub. Checking manually, or enabling automatic checks, makes network requests to GitHub and its download infrastructure. As with other web requests, those services receive your IP address and request information, which may include app and operating-system version information. Vault contents are not included.

Automatic checking is off by default and can be disabled in Settings → Updates. Downloads and installation are user-initiated, and Sparkle system profiling is disabled. This updater is not used by the iPhone or iPad app; App Store updates are handled by Apple.

See the [GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) for GitHub's handling and retention of request information.

## Support and privacy requests

If you contact us, we receive the information you choose to share, such as your message, contact details, screenshots or diagnostic files. We use it to respond to your request and investigate the reported problem. Please avoid sending private task content unless it is needed for the issue.

To contact the Taskmark maintainer about privacy or request access, correction or deletion of information you have sent us, open a minimal [Privacy contact request on GitHub](https://github.com/domness/taskmark/issues/new?title=Privacy%20contact%20request). A maintainer will arrange a private channel. GitHub issues are public: do not include personal information, vault contents or details of your request in the public issue. GitHub processes information submitted through its service under its own privacy statement.

We retain support correspondence only for as long as needed to handle the request and related follow-up, or meet applicable legal obligations. You can request deletion through the contact route above. We cannot access or delete files held only on your devices or by your chosen storage provider.

## Retention, deletion and your choices

Your vault remains where you placed it until you delete or move it. Deleting Taskmark does not delete a vault stored outside the app's own storage. You can inspect, copy, export or delete your vault files using your device's file tools without a Taskmark account or permission from us.

Taskmark may retain unsaved mobile recovery copies until they are saved or discarded. To remove the iPhone or iPad app's local data, delete the app through system settings; offloading the app retains its data. Separately delete any vault files you want removed. On macOS, removing the app may leave local preferences and folder bookmarks behind.

Copies in cloud storage, recently deleted folders and backups are governed by the relevant provider's retention settings. Remove those copies through that provider if you want them deleted. You can stop Taskmark accessing a vault by closing it or selecting another folder, disable automatic macOS update checks, and choose not to send support information.

## Protecting your information

Taskmark relies on your device's security and your chosen file provider's protections. It does not add its own encryption to vault files. Anyone or any app with permission to read your vault can read its contents. Use device access controls, disk encryption and suitable storage permissions for sensitive information.

## Changes to this policy

We will update this document when Taskmark's privacy practices change and revise the date above. The current policy is available in the [Taskmark repository](https://github.com/domness/taskmark/blob/main/PRIVACY.md).
