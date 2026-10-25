# Contributing to BIOS Viewer

Thank you for helping improve BIOS Viewer, created by Purple Dragon Foundation Ltd. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before starting

Search existing issues and pull requests. For a substantial feature or architectural change, open a feature request first so the implementation can be discussed. Report security vulnerabilities privately using [SECURITY.md](SECURITY.md).

The app targets Windows PowerShell 5.1 and Windows Forms. Keep it portable and avoid new dependencies unless their need and distribution are agreed with the maintainer.

## Local workflow

1. Clone the repository or extract its source ZIP into a writable directory.
2. Open **Open BIOS Viewer.cmd** to run the app.
3. Make changes on a focused branch.
4. Run the UI smoke check in Windows PowerShell:

   `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\BIOS Viewer.ps1" -SmokeTest`

5. Test the affected behavior in the running app, then submit a pull request.

The smoke check uses fixture data and does not prove live hardware collection works. For collection changes, verify actual returned fields on Windows, handling of denied queries, responsiveness, and cleanup of background jobs. For UI changes, check both themes, keyboard navigation, window resizing, and Windows display scaling. For report changes, check old snapshot compatibility, comparison, export escaping, and history retention.

## Project structure

- **BIOS Viewer.ps1:** interface, preferences, and background worker coordination.
- **Collect.ps1:** read-only Windows hardware and diagnostic queries.
- **Reports.ps1:** snapshot validation, comparison, retention, and HTML export.
- **Open BIOS Viewer.cmd:** portable launcher.

## Contribution standards

Keep hardware and firmware queries read-only. Do not add firmware writes, automatic elevation, hidden services, network uploads, or automatic driver/firmware updates without a separate design discussion. Unsupported or denied readings must remain unknown, not be interpreted as disabled.

Preserve existing data, branding, and snapshot compatibility. Keep changes focused, remove obsolete declarations during refactors, and avoid duplicate functions or event handlers. Describe what changed and provide relevant validation evidence.

Never commit personal snapshots, preferences, device serials, product keys, credentials, event-log exports, or identifying screenshots. Redact any diagnostic information attached to public issues.

## License

Contributions are provided under the repository's [MIT License](LICENSE). Only submit code and assets you have permission to contribute.
