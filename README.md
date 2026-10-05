# Windows Privacy Conservative

A conservative PowerShell privacy utility for Windows 10 and Windows 11.

The goal is **not** to "debloat Windows at any cost." The goal is to reduce optional telemetry-related and promotional behavior while preserving normal Windows functionality.

## Philosophy

Many Windows tweak tools disable large groups of services, scheduled tasks and policies at once. That can sometimes create side effects involving:

- Windows Update
- printers
- Bluetooth
- USB devices
- networking
- Microsoft Store
- drivers
- application compatibility
- troubleshooting tools

This project takes a different approach:

> **Audit first. Change only what is necessary. Keep the operating system functional.**

The project intentionally favors small, understandable and reversible changes over aggressive debloating.

## What the conservative profile changes

The main profile can:

- disable the Windows advertising ID
- disable tailored experiences based on diagnostic data
- reduce Windows suggestions and promotional content
- disable selected Content Delivery Manager promotional settings
- restrict implicit text and ink personalization
- disable the CEIP scheduled tasks:
  - `Consolidator`
  - `UsbCeip`

Camera and microphone controls are available separately as **optional** choices.

## What it intentionally does NOT disable

This project deliberately leaves the following components alone:

- Windows Update
- Microsoft Defender
- `DiagTrack`
- Print Spooler and printer-related services
- Bluetooth services
- USB/device installation services
- networking services
- Microsoft Compatibility Appraiser
- core Windows diagnostic tasks
- Plug and Play infrastructure
- driver installation infrastructure

It also does **not** delete built-in applications.

## Diagnostic telemetry policy

The script audits:

- `AllowTelemetry`
- `MaxTelemetryAllowed`

The public conservative profile does **not** automatically create or force administrative diagnostic policy values.

This is intentional. Administrative policy changes can cause Windows Settings to display messages such as:

> "Some settings are managed by your organization."

Users who want to manage diagnostic policy should do so deliberately and understand the implications for their Windows edition.

## Safety features

Before applying the conservative profile, the script creates a timestamped JSON backup on the user's actual Desktop path.

Example:

```text
Windows-Privacy-Conservative-Backup\
privacy-backup-20261004-215028.json
```

The script:

- keeps multiple timestamped backups
- lets the user choose which backup to restore
- does not silently overwrite the previous backup
- provides a read-only audit
- provides a preflight self-test before changes are applied
- separates camera/microphone controls from the main privacy profile

## Preflight self-test

The preflight check verifies that:

- Windows is detected
- PowerShell is running with Administrator privileges
- `HKCU` and `HKLM` registry providers are available
- required PowerShell commands are available

The self-test does **not** modify Windows.

## Privacy audit

The audit reports the current state of the privacy-related settings managed or inspected by the project.

It also reports the current status of selected core services for verification only, including:

- Windows Update
- BITS
- Microsoft Defender
- Print Spooler
- Bluetooth Support Service
- Device Install Service
- Plug and Play
- DiagTrack

The script does not disable these services.

A service appearing as `Stopped` with `StartType = Manual` does **not** mean that it is disabled. Many Windows services start on demand.

## Usage

1. Download and extract the release ZIP, or download `Windows-Privacy-Conservative.ps1` directly.
2. Open PowerShell as Administrator.
3. Change to the folder containing the script.
4. If Windows blocks script execution, you can allow scripts only for the current PowerShell process:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

This setting ends when that PowerShell process is closed. A Group Policy can still override it.

5. Run:

```powershell
.\Windows-Privacy-Conservative.ps1
```

## Menu

```text
1. Preflight self-test (no changes)
2. Audit only
3. Create backup
4. Apply conservative privacy profile
5. Camera / microphone options
6. Restore a backup
7. Exit
```


### Clean exit behavior

When **Exit** is selected, the script checks whether the current working directory still exists. If the directory was removed or became unavailable, the script returns PowerShell to the user's home folder before closing. It then displays:

```text
Exiting Windows Privacy Conservative.
No further changes were made.
```

This avoids confusing shell messages caused by an unavailable working directory after the script exits.

## Recommended workflow

For a new system:

1. Run **Preflight self-test**.
2. Run **Audit only**.
3. Review the results.
4. Create a backup.
5. Apply the conservative privacy profile.
6. Run **Audit only** again.
7. Verify Windows Update and your normal hardware/devices.
8. Restore a backup if necessary.

Do not apply privacy tweaks blindly to a production system.

## Tested

The complete workflow has been tested successfully on both **Windows 11** and **Windows 10**.

### Windows 11

Verified on **October 4, 2026**:

- PowerShell syntax validation
- script startup and menu loading
- preflight self-test
- read-only privacy audit
- timestamped backup creation
- conservative privacy profile application
- post-application audit
- backup selection and restoration
- final audit after restoration

### Windows 10

Verified on **October 5, 2026** using the same workflow:

- preflight self-test
- read-only privacy audit
- timestamped backup creation
- conservative privacy profile application
- post-application audit
- backup selection and restoration
- final audit after restoration

On the tested Windows 10 system, the conservative profile successfully changed the selected Content Delivery Manager values from `1` to `0`, changed implicit text/ink collection restrictions from `0` to `1`, and changed the CEIP tasks `Consolidator` and `UsbCeip` from `Ready` to `Disabled`.

After restoring the pre-apply backup, those tested values and task states returned to their original Windows 10 state.

During both Windows 10 and Windows 11 testing, Windows Update, BITS, Microsoft Defender, `DiagTrack`, Print Spooler, Bluetooth, Device Install Service and Plug and Play remained enabled or in their normal on-demand states.

Successful testing on these systems does **not** guarantee identical behavior on every Windows edition, OEM image, managed PC or future build. Run the preflight check and audit, create a backup, and verify your own hardware and applications after applying changes.

## Implementation notes

Several settings used by this project are ordinary Windows registry values rather than a public, versioned programming API.

In particular, some `ContentDeliveryManager` values are internal Windows implementation details. They were verified on the Windows 10 and Windows 11 systems used for this release, but Microsoft can change or remove them in future builds.

For that reason, the script:

- audits before changing anything
- creates timestamped backups
- tolerates missing CEIP tasks
- avoids treating every missing registry value as an error
- avoids disabling core services to compensate for undocumented behavior

The diagnostic-data values are shown for visibility only. The conservative profile does not force the administrative diagnostic-data policy.

## Compatibility

Designed for Windows 10 and Windows 11.

Windows internals change over time, so registry values, scheduled tasks and default service behavior may differ between Windows 10 and Windows 11, and between:

- Windows editions
- Windows builds
- OEM installations
- managed environments
- future Windows releases

Missing settings or tasks are not automatically treated as failures.

## Important limitations

This project has been tested successfully on Windows 10 and Windows 11 systems, but that does **not** guarantee identical behavior on every computer.

Before applying changes:

- run the audit
- create a backup
- review the source code
- verify your own hardware and applications after applying the profile

If your PC is managed by an employer, school or organization, do not override administrative policies without authorization.

## Why this project exists

The goal is not to produce the smallest possible Windows installation or disable every Microsoft service.

The goal is:

> **Improve privacy without unnecessarily breaking Windows functionality.**

Printers should still print.

Bluetooth devices should still connect.

USB devices should still install.

Windows Update should still work.

Defender should still protect the system.

Drivers and compatibility tools should remain available.

That is the design philosophy of this project.

## Reporting issues

If you find a problem, include:

- Windows edition
- Windows version/build
- PowerShell version
- the option you selected
- the relevant audit output
- the error message
- whether restoring the backup resolved the issue

Do not include passwords, private account information or other sensitive personal data in GitHub issues.

## Disclaimer

Use at your own risk.

This project intentionally avoids aggressive system modifications, but no Windows configuration script can guarantee identical behavior on every PC, Windows edition, OEM image or future Windows build.

Always review the source before running it.

## License

MIT License. See `LICENSE`.

## Credits

**Project author: Soto.**

Technical and documentation assistance: ChatGPT (OpenAI).

The testing, configuration decisions and verification methodology were performed by Soto. ChatGPT was used as support for analysis, organization and documentation.## Version

Current release: **v1.1.0** — tested on Windows 10 and Windows 11.


