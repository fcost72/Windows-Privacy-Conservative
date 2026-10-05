<#
.SYNOPSIS
    Windows Privacy Conservative
.DESCRIPTION
    Conservative privacy tuning for Windows 10 and Windows 11.

    Design goals:
    - Do not disable Windows Update.
    - Do not disable Microsoft Defender.
    - Do not disable DiagTrack.
    - Do not disable compatibility/diagnostic infrastructure.
    - Do not disable printing, Bluetooth, networking, USB or device services.
    - Do not delete built-in applications.
    - Do not apply large "debloat" bundles.
    - Back up values before changing them.
    - Make changes easy to audit and reverse.

.NOTES
    Project author: Soto
    Technical/documentation assistance: ChatGPT (OpenAI)

    Recommended: Run PowerShell as Administrator.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:ProjectName = "Windows-Privacy-Conservative"
$Script:DesktopPath = [Environment]::GetFolderPath("Desktop")
$Script:BackupRoot = Join-Path $Script:DesktopPath "$Script:ProjectName-Backup"

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ""
    Write-Host ("=" * 76)
    Write-Host $Title
    Write-Host ("=" * 76)
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsInfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cv = Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
            -ErrorAction SilentlyContinue

        [pscustomobject]@{
            Caption        = $os.Caption
            Version        = $os.Version
            BuildNumber    = $os.BuildNumber
            DisplayVersion = $cv.DisplayVersion
        }
    }
    catch {
        [pscustomobject]@{
            Caption        = "Windows"
            Version        = "<unknown>"
            BuildNumber    = "<unknown>"
            DisplayVersion = $null
        }
    }
}

function Get-RegValueSafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )

    if (-not (Test-Path $Path)) {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        [pscustomobject]@{ Exists = $true; Value = $item.$Name }
    }
    catch {
        [pscustomobject]@{ Exists = $false; Value = $null }
    }
}

function Set-DwordValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

function Set-StringValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
}

function Restore-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$BackupEntry
    )

    if ($BackupEntry.Exists -eq $true) {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue

        if ($null -ne $existing) {
            Set-ItemProperty -Path $Path -Name $Name -Value $BackupEntry.Value
        }
        else {
            if ($BackupEntry.Value -is [int] -or $BackupEntry.Value -is [long]) {
                New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value ([int]$BackupEntry.Value) -Force | Out-Null
            }
            else {
                New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value ([string]$BackupEntry.Value) -Force | Out-Null
            }
        }
    }
    else {
        if (Test-Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        }
    }
}

function Get-CeipTaskState {
    param([Parameter(Mandatory)][string]$TaskName)

    try {
        $task = Get-ScheduledTask `
            -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" `
            -TaskName $TaskName `
            -ErrorAction Stop

        return $task.State.ToString()
    }
    catch {
        return "NotFound"
    }
}

function Test-Environment {
    Write-Section "PREFLIGHT SELF-TEST"

    $isWindows = $env:OS -eq "Windows_NT"
    $isAdmin = $false

    if ($isWindows) {
        try { $isAdmin = Test-IsAdmin } catch { $isAdmin = $false }
    }

    $requiredCommands = @(
        "Get-ScheduledTask",
        "Disable-ScheduledTask",
        "Enable-ScheduledTask",
        "Get-CimInstance",
        "Get-NetTCPConnection",
        "Get-Service"
    )

    $commandResults = foreach ($name in $requiredCommands) {
        [pscustomobject]@{
            Command = $name
            Available = [bool](Get-Command $name -ErrorAction SilentlyContinue)
        }
    }

    $basicChecks = @(
        [pscustomobject]@{
            Check = "Windows"
            Result = $isWindows
        }
        [pscustomobject]@{
            Check = "Administrator"
            Result = $isAdmin
        }
        [pscustomobject]@{
            Check = "HKCU registry provider"
            Result = [bool](Get-PSDrive HKCU -ErrorAction SilentlyContinue)
        }
        [pscustomobject]@{
            Check = "HKLM registry provider"
            Result = [bool](Get-PSDrive HKLM -ErrorAction SilentlyContinue)
        }
    )

    $basicChecks | Format-Table -AutoSize

    if ($isWindows) {
        $windowsInfo = Get-WindowsInfo
        Write-Host ""
        Write-Host "Detected Windows:"
        Write-Host ("  Operating system: " + $windowsInfo.Caption)
        Write-Host ("  Version: " + $windowsInfo.Version)
        Write-Host ("  Build: " + $windowsInfo.BuildNumber)
        if ($windowsInfo.DisplayVersion) {
            Write-Host ("  Display version: " + $windowsInfo.DisplayVersion)
        }
    }

    Write-Host ""
    $commandResults | Format-Table -AutoSize

    $failed = @($commandResults | Where-Object { -not $_.Available })

    if (-not $isWindows) {
        Write-Warning "This script is intended for Windows 10 and Windows 11."
    }

    if (-not $isAdmin) {
        Write-Warning "Audit can still work partially, but applying/restoring should be run as Administrator."
    }

    if ($failed.Count -gt 0) {
        Write-Warning "One or more required PowerShell commands are unavailable on this system."
    }
    else {
        Write-Host "Required PowerShell commands are available."
    }
}

function Backup-PrivacySettings {
    Write-Section "CREATING BACKUP"

    New-Item -ItemType Directory -Path $Script:BackupRoot -Force | Out-Null

    $dataCollection = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    $advertising = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    $privacy = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    $content = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $input = "HKCU:\Software\Microsoft\InputPersonalization"
    $microphone = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    $webcam = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"

    $backup = [ordered]@{
        Timestamp = (Get-Date).ToString("o")

        Registry = [ordered]@{
            AllowTelemetry = Get-RegValueSafe $dataCollection "AllowTelemetry"
            MaxTelemetryAllowed = Get-RegValueSafe $dataCollection "MaxTelemetryAllowed"

            AdvertisingEnabled = Get-RegValueSafe $advertising "Enabled"
            TailoredExperiences = Get-RegValueSafe $privacy "TailoredExperiencesWithDiagnosticDataEnabled"

            SystemPaneSuggestionsEnabled = Get-RegValueSafe $content "SystemPaneSuggestionsEnabled"
            SoftLandingEnabled = Get-RegValueSafe $content "SoftLandingEnabled"
            ContentDeliveryAllowed = Get-RegValueSafe $content "ContentDeliveryAllowed"
            OemPreInstalledAppsEnabled = Get-RegValueSafe $content "OemPreInstalledAppsEnabled"
            PreInstalledAppsEnabled = Get-RegValueSafe $content "PreInstalledAppsEnabled"
            PreInstalledAppsEverEnabled = Get-RegValueSafe $content "PreInstalledAppsEverEnabled"
            SilentInstalledAppsEnabled = Get-RegValueSafe $content "SilentInstalledAppsEnabled"
            SubscribedContent338389 = Get-RegValueSafe $content "SubscribedContent-338389Enabled"

            RestrictImplicitTextCollection = Get-RegValueSafe $input "RestrictImplicitTextCollection"
            RestrictImplicitInkCollection = Get-RegValueSafe $input "RestrictImplicitInkCollection"

            Microphone = Get-RegValueSafe $microphone "Value"
            Webcam = Get-RegValueSafe $webcam "Value"
        }

        ScheduledTasks = [ordered]@{
            Consolidator = Get-CeipTaskState "Consolidator"
            UsbCeip = Get-CeipTaskState "UsbCeip"
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = Join-Path $Script:BackupRoot "privacy-backup-$timestamp.json"

    $backup | ConvertTo-Json -Depth 8 | Set-Content -Path $backupFile -Encoding UTF8

    Write-Host "Backup saved to:"
    Write-Host $backupFile

    return $backupFile
}

function Show-PrivacyAudit {
    Write-Section "WINDOWS PRIVACY AUDIT"

    $windowsInfo = Get-WindowsInfo
    Write-Host ("Operating system: " + $windowsInfo.Caption)
    Write-Host ("Build: " + $windowsInfo.BuildNumber)
    if ($windowsInfo.DisplayVersion) {
        Write-Host ("Display version: " + $windowsInfo.DisplayVersion)
    }
    Write-Host ""

    $dataCollection = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    $advertising = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    $privacy = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    $content = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $input = "HKCU:\Software\Microsoft\InputPersonalization"
    $microphone = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    $webcam = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"

    $rows = [System.Collections.Generic.List[object]]::new()

    function Add-AuditRow {
        param($Area, $Setting, $Value, $ConservativeTarget, $Action)

        $row = [pscustomobject]@{
            Area = $Area
            Setting = $Setting
            Current = if ($null -eq $Value) { "<not set>" } else { [string]$Value }
            ConservativeTarget = $ConservativeTarget
            Action = $Action
        }

        $rows.Add($row)
    }

    # Diagnostic level is audited only. The public conservative profile does NOT
    # force administrative telemetry policy keys.
    Add-AuditRow "Diagnostics" "AllowTelemetry" `
        (Get-RegValueSafe $dataCollection "AllowTelemetry").Value `
        "1 is commonly used for required/basic" `
        "AUDIT ONLY"

    Add-AuditRow "Diagnostics" "MaxTelemetryAllowed" `
        (Get-RegValueSafe $dataCollection "MaxTelemetryAllowed").Value `
        "1 if already configured" `
        "AUDIT ONLY"

    Add-AuditRow "Advertising" "Advertising ID" `
        (Get-RegValueSafe $advertising "Enabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Privacy" "Tailored experiences" `
        (Get-RegValueSafe $privacy "TailoredExperiencesWithDiagnosticDataEnabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Content" "SystemPaneSuggestionsEnabled" `
        (Get-RegValueSafe $content "SystemPaneSuggestionsEnabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Content" "SoftLandingEnabled" `
        (Get-RegValueSafe $content "SoftLandingEnabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Content" "ContentDeliveryAllowed" `
        (Get-RegValueSafe $content "ContentDeliveryAllowed").Value "0" "SAFE PROFILE"

    Add-AuditRow "Content" "OemPreInstalledAppsEnabled" `
        (Get-RegValueSafe $content "OemPreInstalledAppsEnabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Content" "PreInstalledAppsEnabled" `
        (Get-RegValueSafe $content "PreInstalledAppsEnabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Content" "SilentInstalledAppsEnabled" `
        (Get-RegValueSafe $content "SilentInstalledAppsEnabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Content" "SubscribedContent-338389Enabled" `
        (Get-RegValueSafe $content "SubscribedContent-338389Enabled").Value "0" "SAFE PROFILE"

    Add-AuditRow "Typing" "RestrictImplicitTextCollection" `
        (Get-RegValueSafe $input "RestrictImplicitTextCollection").Value "1" "SAFE PROFILE"

    Add-AuditRow "Typing" "RestrictImplicitInkCollection" `
        (Get-RegValueSafe $input "RestrictImplicitInkCollection").Value "1" "SAFE PROFILE"

    Add-AuditRow "Permissions" "Microphone" `
        (Get-RegValueSafe $microphone "Value").Value "User choice" "OPTIONAL"

    Add-AuditRow "Permissions" "Webcam" `
        (Get-RegValueSafe $webcam "Value").Value "User choice" "OPTIONAL"

    $rows | Format-Table -AutoSize

    Write-Section "CEIP TASKS"

    $ceipTasks = @(
        [pscustomobject]@{
            Task = "Consolidator"
            State = Get-CeipTaskState "Consolidator"
            ConservativeProfile = "Disabled"
        }
        [pscustomobject]@{
            Task = "UsbCeip"
            State = Get-CeipTaskState "UsbCeip"
            ConservativeProfile = "Disabled"
        }
    )

    $ceipTasks | Format-Table -AutoSize

    Write-Section "DIAGTRACK STATUS"

    Get-Service DiagTrack -ErrorAction SilentlyContinue |
        Select-Object Name, DisplayName, Status, StartType |
        Format-Table -AutoSize

    try {
        $pidDiag = (Get-CimInstance Win32_Service -Filter "Name='DiagTrack'").ProcessId

        if ($pidDiag -gt 0) {
            $connections = Get-NetTCPConnection -OwningProcess $pidDiag -ErrorAction SilentlyContinue |
                Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State

            if ($connections) {
                Write-Host ""
                Write-Host "Active TCP connections owned by the DiagTrack process:"
                $connections | Format-Table -AutoSize
            }
            else {
                Write-Host ""
                Write-Host "DiagTrack has no active TCP connections at this instant."
            }
        }
    }
    catch {
        Write-Host "Could not query DiagTrack network connections."
    }

    Write-Section "CORE SERVICES STATUS (READ ONLY)"

    $coreServiceNames = @(
        "wuauserv",
        "BITS",
        "WinDefend",
        "Spooler",
        "bthserv",
        "DeviceInstall",
        "PlugPlay"
    )

    $coreServices = foreach ($serviceName in $coreServiceNames) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -ne $service) {
            [pscustomobject]@{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = $service.Status
                StartType = $service.StartType
            }
        }
        else {
            [pscustomobject]@{
                Name = $serviceName
                DisplayName = "<not present>"
                Status = "-"
                StartType = "-"
            }
        }
    }

    $coreServices | Format-Table -AutoSize

    Write-Section "SAFETY SCOPE"
    Write-Host "This project intentionally does NOT disable:"
    Write-Host "  - Windows Update"
    Write-Host "  - Microsoft Defender"
    Write-Host "  - DiagTrack"
    Write-Host "  - Print Spooler / printer services"
    Write-Host "  - Bluetooth services"
    Write-Host "  - USB/device installation services"
    Write-Host "  - Networking services"
    Write-Host "  - Compatibility Appraiser"
    Write-Host "  - Core diagnostic tasks"
}

function Apply-ConservativePrivacyProfile {
    if (-not (Test-IsAdmin)) {
        Write-Warning "Run PowerShell as Administrator before applying changes."
        return
    }

    Backup-PrivacySettings
    Write-Section "APPLYING CONSERVATIVE PROFILE"

    $advertising = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    $privacy = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    $content = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $input = "HKCU:\Software\Microsoft\InputPersonalization"

    # Deliberately do NOT create or force Windows diagnostic policy values here.
    # This avoids turning the public profile into an administrative-policy tweaker.

    Set-DwordValue $advertising "Enabled" 0
    Set-DwordValue $privacy "TailoredExperiencesWithDiagnosticDataEnabled" 0

    Set-DwordValue $content "SystemPaneSuggestionsEnabled" 0
    Set-DwordValue $content "SoftLandingEnabled" 0
    Set-DwordValue $content "ContentDeliveryAllowed" 0
    Set-DwordValue $content "OemPreInstalledAppsEnabled" 0
    Set-DwordValue $content "PreInstalledAppsEnabled" 0
    Set-DwordValue $content "SilentInstalledAppsEnabled" 0
    Set-DwordValue $content "SubscribedContent-338389Enabled" 0

    Set-DwordValue $input "RestrictImplicitTextCollection" 1
    Set-DwordValue $input "RestrictImplicitInkCollection" 1

    foreach ($taskName in @("Consolidator", "UsbCeip")) {
        try {
            Disable-ScheduledTask `
                -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" `
                -TaskName $taskName `
                -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Could not disable $taskName, or the task does not exist on this Windows build."
        }
    }

    Write-Host ""
    Write-Host "Conservative profile applied."
    Write-Host "Camera and microphone were NOT changed automatically."
    Write-Host "Windows Update, Defender, DiagTrack, printing, Bluetooth, USB and compatibility were left intact."
}

function Set-OptionalDevicePrivacy {
    if (-not (Test-IsAdmin)) {
        Write-Warning "Run PowerShell as Administrator."
        return
    }

    $microphone = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    $webcam = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"

    Write-Host ""
    Write-Host "Optional device privacy"
    Write-Host "1. Block microphone for current user"
    Write-Host "2. Allow microphone for current user"
    Write-Host "3. Block webcam for current user"
    Write-Host "4. Allow webcam for current user"
    Write-Host "5. Return"

    $choice = Read-Host "Choose"

    if ($choice -in @("1","2","3","4")) {
        Backup-PrivacySettings | Out-Null
    }

    switch ($choice) {
        "1" { Set-StringValue $microphone "Value" "Deny"; Write-Host "Microphone: Deny" }
        "2" { Set-StringValue $microphone "Value" "Allow"; Write-Host "Microphone: Allow" }
        "3" { Set-StringValue $webcam "Value" "Deny"; Write-Host "Webcam: Deny" }
        "4" { Set-StringValue $webcam "Value" "Allow"; Write-Host "Webcam: Allow" }
        default { }
    }
}

function Restore-PrivacyBackup {
    if (-not (Test-IsAdmin)) {
        Write-Warning "Run PowerShell as Administrator before restoring."
        return
    }

    if (-not (Test-Path $Script:BackupRoot)) {
        Write-Warning "Backup folder not found: $Script:BackupRoot"
        return
    }

    $backupFiles = @(Get-ChildItem -Path $Script:BackupRoot -Filter "privacy-backup-*.json" -File |
        Sort-Object LastWriteTime -Descending)

    if ($backupFiles.Count -eq 0) {
        Write-Warning "No backup files were found in: $Script:BackupRoot"
        return
    }

    Write-Section "AVAILABLE BACKUPS"

    for ($i = 0; $i -lt $backupFiles.Count; $i++) {
        Write-Host ("{0}. {1}  ({2})" -f ($i + 1), $backupFiles[$i].Name, $backupFiles[$i].LastWriteTime)
    }

    $selection = Read-Host "Choose backup number (Enter = newest)"
    if ([string]::IsNullOrWhiteSpace($selection)) {
        $index = 0
    }
    elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $backupFiles.Count) {
        $index = [int]$selection - 1
    }
    else {
        Write-Warning "Invalid backup selection."
        return
    }

    $backupFile = $backupFiles[$index].FullName

    Write-Section "RESTORING BACKUP"
    Write-Host "Using: $backupFile"

    $backup = Get-Content -Path $backupFile -Raw | ConvertFrom-Json

    $dataCollection = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    $advertising = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    $privacy = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    $content = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $input = "HKCU:\Software\Microsoft\InputPersonalization"
    $microphone = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    $webcam = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"

    Restore-RegValue $dataCollection "AllowTelemetry" $backup.Registry.AllowTelemetry
    Restore-RegValue $dataCollection "MaxTelemetryAllowed" $backup.Registry.MaxTelemetryAllowed

    Restore-RegValue $advertising "Enabled" $backup.Registry.AdvertisingEnabled
    Restore-RegValue $privacy "TailoredExperiencesWithDiagnosticDataEnabled" $backup.Registry.TailoredExperiences

    Restore-RegValue $content "SystemPaneSuggestionsEnabled" $backup.Registry.SystemPaneSuggestionsEnabled
    Restore-RegValue $content "SoftLandingEnabled" $backup.Registry.SoftLandingEnabled
    Restore-RegValue $content "ContentDeliveryAllowed" $backup.Registry.ContentDeliveryAllowed
    Restore-RegValue $content "OemPreInstalledAppsEnabled" $backup.Registry.OemPreInstalledAppsEnabled
    Restore-RegValue $content "PreInstalledAppsEnabled" $backup.Registry.PreInstalledAppsEnabled
    Restore-RegValue $content "PreInstalledAppsEverEnabled" $backup.Registry.PreInstalledAppsEverEnabled
    Restore-RegValue $content "SilentInstalledAppsEnabled" $backup.Registry.SilentInstalledAppsEnabled
    Restore-RegValue $content "SubscribedContent-338389Enabled" $backup.Registry.SubscribedContent338389

    Restore-RegValue $input "RestrictImplicitTextCollection" $backup.Registry.RestrictImplicitTextCollection
    Restore-RegValue $input "RestrictImplicitInkCollection" $backup.Registry.RestrictImplicitInkCollection

    Restore-RegValue $microphone "Value" $backup.Registry.Microphone
    Restore-RegValue $webcam "Value" $backup.Registry.Webcam

    foreach ($taskName in @("Consolidator", "UsbCeip")) {
        $state = $backup.ScheduledTasks.$taskName

        if ($state -eq "Disabled") {
            Disable-ScheduledTask `
                -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" `
                -TaskName $taskName `
                -ErrorAction SilentlyContinue | Out-Null
        }
        elseif ($state -ne "NotFound") {
            Enable-ScheduledTask `
                -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" `
                -TaskName $taskName `
                -ErrorAction SilentlyContinue | Out-Null
        }
    }

    Write-Host "Backup restored."
}

function Show-Menu {
    Clear-Host
    Write-Host "Windows Privacy Conservative"
    Write-Host "Author: Soto"
    Write-Host ""
    Write-Host "1. Preflight self-test (no changes)"
    Write-Host "2. Audit only"
    Write-Host "3. Create backup"
    Write-Host "4. Apply conservative privacy profile"
    Write-Host "5. Camera / microphone options"
    Write-Host "6. Restore a backup"
    Write-Host "7. Exit"
    Write-Host ""
}

do {
    Show-Menu
    $choice = Read-Host "Select an option"

    switch ($choice) {
        "1" {
            Test-Environment
            Read-Host "Press Enter to return"
        }
        "2" {
            Show-PrivacyAudit
            Read-Host "Press Enter to return"
        }
        "3" {
            Backup-PrivacySettings | Out-Null
            Read-Host "Press Enter to return"
        }
        "4" {
            Write-Host ""
            Write-Host "This profile intentionally leaves Windows Update, Defender,"
            Write-Host "DiagTrack, printing, Bluetooth, USB, networking and compatibility intact."
            $confirm = Read-Host "Type YES to apply"
            if ($confirm -eq "YES") {
                Apply-ConservativePrivacyProfile
            }
            else {
                Write-Host "Cancelled."
            }
            Read-Host "Press Enter to return"
        }
        "5" {
            Set-OptionalDevicePrivacy
            Read-Host "Press Enter to return"
        }
        "6" {
            $confirm = Read-Host "Type YES to choose and restore a backup"
            if ($confirm -eq "YES") {
                Restore-PrivacyBackup
            }
            else {
                Write-Host "Cancelled."
            }
            Read-Host "Press Enter to return"
        }
        "7" {
            try {
                $currentPath = (Get-Location).Path
                if (-not (Test-Path -LiteralPath $currentPath)) {
                    Set-Location -Path $HOME
                }
            }
            catch {
                Set-Location -Path $HOME
            }

            Write-Host ""
            Write-Host "Exiting Windows Privacy Conservative."
            Write-Host "No further changes were made."
            break
        }
        default {
            Write-Host "Invalid option."
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "7")
