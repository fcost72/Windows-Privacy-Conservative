# Changelog

## v1.1.0 — 2026-10-05

### Added
- Tested support for Windows 10.
- Automatic Windows version/build reporting in preflight and audit output.
- Windows 10 validation notes in the README.

### Changed
- Public-facing project name generalized to **Windows Privacy Conservative**.
- Main script renamed to `Windows-Privacy-Conservative.ps1`.
- Audit heading generalized to `WINDOWS PRIVACY AUDIT`.
- Backup folder name generalized to `Windows-Privacy-Conservative-Backup`.

### Verified
The complete workflow was tested on Windows 10 and Windows 11:

Preflight → Audit → Backup → Apply → Audit → Restore → Final Audit.

Core Windows services remained available during testing.
