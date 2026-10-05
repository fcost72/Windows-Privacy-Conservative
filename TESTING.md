# Testing Checklist

Run these checks on a Windows 11 test machine before publishing a release.

## 1. Parse the script without running it

Open PowerShell and run:

```powershell
$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\Windows11-Privacy-Conservative.ps1),
    [ref]$tokens,
    [ref]$errors
) | Out-Null

$errors
```

Expected result: **no output**.

If PowerShell prints a parser error, do not publish that version.

## 2. Run the preflight self-test

Run PowerShell as Administrator. If needed for the current process only:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

Then run:

```powershell
.\Windows11-Privacy-Conservative.ps1
```

Choose:

```text
1. Preflight self-test (no changes)
```

Confirm that Windows, Administrator, HKCU, HKLM and the required cmdlets are available.

## 3. Run Audit only

Choose:

```text
2. Audit only
```

The audit must complete without terminating errors.

Verify that it reports:

- privacy registry values
- CEIP tasks
- DiagTrack status
- DiagTrack TCP connections, if any exist at that instant
- Windows Update (`wuauserv`)
- BITS
- Defender (`WinDefend`)
- Print Spooler
- Bluetooth Support Service (`bthserv`)
- Device Install
- Plug and Play

The service report is informational only. Some Windows services normally use trigger/manual start and may be stopped when idle.

## 4. Create a backup

Choose:

```text
3. Create backup
```

Verify a timestamped JSON file appears on the Desktop under:

```text
Windows11-Privacy-Conservative-Backup
```

Open the JSON file and confirm it is readable.

## 5. Apply the conservative profile

Choose:

```text
4. Apply conservative privacy profile
```

Type:

```text
YES
```

The script should create another backup before changing anything.

Run **Audit only** again.

Confirm the intended values changed while the protected services were not modified.

## 6. Functional smoke tests

After applying the profile, test:

- Windows Update opens and checks for updates
- Microsoft Defender / Windows Security opens normally
- Internet access works
- Microsoft Store opens, if installed
- a USB device can be detected
- printer detection/printing works if a printer is available
- Bluetooth settings open and devices can connect if Bluetooth hardware is available

The script does not modify those services, but these checks provide release evidence.

## 7. Camera and microphone

Camera/microphone changes are optional and separate from the conservative profile.

If testing them:

1. Choose the camera/microphone menu.
2. Block one device permission.
3. Confirm Windows privacy settings reflect the change.
4. Restore it to `Allow`.
5. Confirm the setting is restored.

## 8. Restore test

Choose:

```text
6. Restore a backup
```

Select the backup created before the profile was applied.

Run **Audit only** again and confirm the saved values were restored.

## 9. Restart test

Restart Windows.

Repeat:

- preflight
- audit
- Windows Update check
- printer/USB/Bluetooth smoke tests as applicable

Only publish a release after the script passes the parser check, audit, apply, restore and restart tests.
