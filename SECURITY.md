# Security Policy

## Supported versions

Security fixes are considered for the latest published release and the current main branch. Older releases do not have a separate maintenance commitment. This is a small project with no guaranteed response or fix deadline.

## Report a vulnerability privately

Use [GitHub's private vulnerability reporting form](https://github.com/bubblegump30/BIOSViewer/security/advisories/new). Private vulnerability reporting is enabled for this repository.

Include the affected version, a concise description, impact, steps to reproduce, and a minimal proof of concept when appropriate. Remove credentials, product keys, personal hardware identifiers, and unrelated event-log data.

Do not publish vulnerability details or exploit code in public issues before the maintainer has had an opportunity to review the report. Do not test against other people's machines or data.

## Security scope

BIOS Viewer reads Windows-reported system information. It does not intentionally modify firmware, install drivers, run a service, or elevate itself. Running it as administrator broadens access to system information; review the code and run it without elevation when those extra readings are unnecessary.

Snapshots, exported reports, screenshots, and event messages may reveal system details. They remain local unless you choose to share them. Review and redact diagnostic attachments before posting.

Release checksums and VirusTotal reports help identify a particular artifact and its observed scan result. They are not a guarantee of safety and do not apply automatically to changed files or later releases.

## Updates

Obtain releases from [this repository's Releases page](https://github.com/bubblegump30/BIOSViewer/releases). When a security fix is published, its release notes should explain the affected behavior and any required user action.
