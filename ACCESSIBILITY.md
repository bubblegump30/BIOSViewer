# Accessibility

Purple Dragon Foundation Ltd aims to make BIOS Viewer useful to people with different access needs. Accessibility feedback and focused improvements are welcome.

## Environment and existing features

BIOS Viewer is a Windows Forms application for Windows with Windows PowerShell 5.1. It includes Light and Dark Mode, resizable windows, native buttons and tables, selectable text in reports, search, and an HTML export that can be opened in a browser.

Standard Windows controls offer keyboard navigation in many parts of the app. The profile and website links have accessible names.

## Known limitations and verification gaps

- The app has not undergone a formal accessibility audit or a complete screen-reader test.
- Tab order, table announcements, focus visibility, high-contrast mode, magnification, and large text have not been comprehensively validated.
- Fixed-height areas can constrain text at some display scaling or text-size settings.
- Snapshot differences use color highlighting, with textual Added, Changed, and Removed labels in the comparison table.
- Native title bars, tabs, drop-downs, and dialogs can follow Windows styling rather than the app theme.
- Dark Mode and a resizable window do not establish accessibility conformance. No WCAG conformance claim is made.

## Report a barrier

Open an [accessibility issue](https://github.com/bubblegump30/BIOSViewer/issues/new?template=accessibility.md). Describe the affected screen, expected behavior, Windows version, display scaling, and assistive technology when relevant. Include steps to reproduce and only redacted screenshots or reports.

Please avoid sharing medical information or other private details. A diagnosis is not needed to describe an accessibility barrier. Reports are reviewed on a best-effort basis; there is no guaranteed response or remediation date.
