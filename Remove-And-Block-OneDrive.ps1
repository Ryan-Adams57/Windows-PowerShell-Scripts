<#
.SYNOPSIS
    Uninstalls Microsoft OneDrive, removes its related data, and sets a permanent
    machine-wide policy block so Windows cannot re-install or re-enable it.

.DESCRIPTION
    SCRIPT HIGHLIGHTS
      - Stops OneDrive, runs every OneDriveSetup.exe /uninstall it can locate
        (System32, SysWOW64, and the per-user Update folder).
      - Removes OneDrive scheduled tasks, the HKCU Run auto-start values, and the
        File Explorer namespace icon.
      - Deletes OneDrive cache/data (LocalAppData, ProgramData, OneDriveTemp).
        The %UserProfile%\OneDrive folder is removed ONLY if empty, to avoid
        deleting local copies of your files.
      - Writes the permanent block: HKLM policy DisableFileSyncNGSC = 1 and
        DisableFileSync = 1. This is the only mechanism Microsoft honors across
        feature updates.
      - Strips the OneDriveSetup stub from the Default user hive so NEW Windows
        profiles never auto-install OneDrive.
      - Creates a boot-time SYSTEM scheduled task (Reassert-OneDrive-Block) that
        re-writes the policy keys after every system update, and hardens the
        C:\Scripts folder ACL because that task runs as SYSTEM.

    REQUIREMENTS
      - Windows 10 or Windows 11, local Administrator.
      - Windows PowerShell 5.1 or PowerShell 7+.
      - Non-domain / consumer machine assumed. On an Intune/MDM or domain-managed
        PC, a tenant OneDrive policy can override these local keys.

    DELIBERATELY OMITTED / POLICY-SENSITIVE
      - Windows Update itself is NOT disabled. This script only prevents OneDrive
        from being re-installed by updates; it does not pause or block updates.
      - The user's %UserProfile%\OneDrive folder is NOT force-deleted when it
        holds files.

    DISCLAIMER
      Provided as-is with no warranty. Test on one machine before wider use.
      Uninstalling OneDrive stops OneDrive file sync; make sure anything stored
      only in OneDrive is backed up elsewhere first.

.PARAMETER WhatIf
    Preview every change without making it. In preview mode no counts are
    reported as completed; the summary is labelled as a preview.

.NOTES
    Windows PowerShell 5.1 or PowerShell 7+.
    Self-elevates to Administrator (every action below requires it).
    If pasted into a console instead of run as a .ps1, elevation is skipped.
    Last Updated: 2026-11-17
#>

#Requires -Version 5.1

# ConfirmImpact is Medium so ShouldProcess drives -WhatIf without firing a
# per-item Y/N prompt on top of the single top-level Confirm-Action gate below.
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Self-elevate to Administrator
# ---------------------------------------------------------------------------
function Test-Admin {
    $id        = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    if ($PSCommandPath) {
        Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
        try {
            Start-Process -FilePath "powershell.exe" `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
                -Verb RunAs -ErrorAction Stop
        } catch {
            Write-Host "Elevation cancelled or failed. Some actions will not work." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
        exit
    } else {
        Write-Host "WARNING: Not running as Administrator. Elevated actions will fail." -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Confirm-Action {
    param([string]$Message)
    $answer = Read-Host "$Message (Y/N)"
    return ($answer -match '^(y|yes)$')
}

function Write-Step {
    # Per-item status line with house color scheme.
    param(
        [Parameter(Mandatory)][ValidateSet('OK', 'Skip', 'Warn', 'Fail', 'Info')][string]$Status,
        [Parameter(Mandatory)][string]$Message
    )
    switch ($Status) {
        'OK'   { Write-Host "  [ OK ]   $Message" -ForegroundColor Green }
        'Skip' { Write-Host "  [SKIP]   $Message" -ForegroundColor DarkGray }
        'Warn' { Write-Host "  [WARN]   $Message" -ForegroundColor Yellow }
        'Fail' { Write-Host "  [FAIL]   $Message" -ForegroundColor Red }
        'Info' { Write-Host "  [INFO]   $Message" -ForegroundColor Cyan }
    }
}

# Tally of changes actually performed (never incremented during -WhatIf).
$script:ChangeCount = 0
function Invoke-Change {
    # Wraps a mutating action behind ShouldProcess so -WhatIf is honest.
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][scriptblock]$Do
    )
    if ($PSCmdlet.ShouldProcess($Target, $Action)) {
        try {
            & $Do
            $script:ChangeCount++
            Write-Step -Status OK -Message "$Action : $Target"
        } catch {
            Write-Step -Status Fail -Message "$Action : $Target  ($($_.Exception.Message))"
        }
    }
}

# ---------------------------------------------------------------------------
# Banner and top-level confirmation
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Remove and Block Microsoft OneDrive" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

if ($WhatIfPreference) {
    Write-Host "Running in PREVIEW (-WhatIf): no changes will be made." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "This will uninstall OneDrive for the current user, remove its data," -ForegroundColor Yellow
    Write-Host "and set a permanent machine-wide policy block. Windows Update is NOT" -ForegroundColor Yellow
    Write-Host "disabled by this script." -ForegroundColor Yellow
    Write-Host ""
    if (-not (Confirm-Action "Proceed")) {
        Write-Host "Cancelled. No changes made." -ForegroundColor Red
        return
    }
}

# ===========================================================================
# 1. Stop OneDrive process
# ===========================================================================
Write-Host "`n[1/7] Stopping OneDrive process..." -ForegroundColor White
$procs = Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue
if ($procs) {
    Invoke-Change -Target 'OneDrive.exe' -Action 'Stop process' -Do {
        $procs | Stop-Process -Force -ErrorAction Stop
    }
} else {
    Write-Step -Status Skip -Message 'OneDrive.exe not running'
}

# ===========================================================================
# 2. Run every OneDriveSetup.exe /uninstall that exists
# ===========================================================================
Write-Host "`n[2/7] Uninstalling OneDrive..." -ForegroundColor White

# Candidate uninstaller locations. System32 is used on 64-bit Windows 11,
# SysWOW64 on legacy 64-bit installs, and the per-user Update folder holds the
# current versioned setup for modern per-user installs.
$setupCandidates = @(
    (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'),
    (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'),
    (Join-Path $env:LocalAppData 'Microsoft\OneDrive\OneDriveSetup.exe'),
    (Join-Path $env:LocalAppData 'Microsoft\OneDrive\Update\OneDriveSetup.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique

if ($setupCandidates.Count -eq 0) {
    Write-Step -Status Skip -Message 'No OneDriveSetup.exe found (may already be removed)'
} else {
    foreach ($setup in $setupCandidates) {
        Invoke-Change -Target $setup -Action 'Run /uninstall' -Do {
            $p = Start-Process -FilePath $setup -ArgumentList '/uninstall' -PassThru -Wait -ErrorAction Stop
            # OneDriveSetup returns quickly; give the uninstaller a moment to settle.
            Start-Sleep -Seconds 3
            if ($p.ExitCode -ne 0) {
                throw "exit code $($p.ExitCode)"
            }
        }
    }
}

# ===========================================================================
# 3. Remove OneDrive scheduled tasks and HKCU auto-start values
# ===========================================================================
Write-Host "`n[3/7] Removing scheduled tasks and auto-start entries..." -ForegroundColor White

$odTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*OneDrive*' }
if ($odTasks) {
    foreach ($t in $odTasks) {
        Invoke-Change -Target $t.TaskName -Action 'Unregister scheduled task' -Do {
            Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction Stop
        }
    }
} else {
    Write-Step -Status Skip -Message 'No OneDrive scheduled tasks present'
}

# Current-user Run values that relaunch OneDrive / its setup.
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
foreach ($valueName in @('OneDrive', 'OneDriveSetup')) {
    $existing = Get-ItemProperty -Path $runKey -Name $valueName -ErrorAction SilentlyContinue
    if ($existing) {
        Invoke-Change -Target "$runKey\$valueName" -Action 'Remove Run value' -Do {
            Remove-ItemProperty -Path $runKey -Name $valueName -ErrorAction Stop
        }
    } else {
        Write-Step -Status Skip -Message "Run value not present: $valueName"
    }
}

# ===========================================================================
# 4. Remove the File Explorer navigation-pane icon
# ===========================================================================
Write-Host "`n[4/7] Removing File Explorer OneDrive icon..." -ForegroundColor White

# The OneDrive namespace CLSID. Setting IsPinnedToNameSpaceTree = 0 hides it
# from the Explorer sidebar. Both 64-bit and WOW6432 views are handled.
$nsClsids = @(
    'HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}',
    'HKLM:\SOFTWARE\Classes\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
)
foreach ($clsid in $nsClsids) {
    if (Test-Path -LiteralPath $clsid) {
        Invoke-Change -Target $clsid -Action 'Hide from Explorer (IsPinnedToNameSpaceTree=0)' -Do {
            New-ItemProperty -Path $clsid -Name 'System.IsPinnedToNameSpaceTree' `
                -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        }
    } else {
        Write-Step -Status Skip -Message "Namespace CLSID not present: $clsid"
    }
}

# ===========================================================================
# 5. Delete OneDrive data and cache
# ===========================================================================
Write-Host "`n[5/7] Removing OneDrive data and cache..." -ForegroundColor White

# Safe to delete: application binaries, cache, and temp. These hold no user docs.
$dataPaths = @(
    (Join-Path $env:LocalAppData 'Microsoft\OneDrive'),
    (Join-Path $env:ProgramData  'Microsoft OneDrive'),
    (Join-Path $env:SystemDrive  'OneDriveTemp')
)
foreach ($path in $dataPaths) {
    if (Test-Path -LiteralPath $path) {
        Invoke-Change -Target $path -Action 'Delete folder' -Do {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
        }
    } else {
        Write-Step -Status Skip -Message "Not present: $path"
    }
}

# The user's OneDrive folder may contain real files. Remove ONLY if empty.
$userOneDrive = Join-Path $env:UserProfile 'OneDrive'
if (Test-Path -LiteralPath $userOneDrive) {
    $items = Get-ChildItem -LiteralPath $userOneDrive -Force -ErrorAction SilentlyContinue
    if ($null -eq $items -or $items.Count -eq 0) {
        Invoke-Change -Target $userOneDrive -Action 'Delete empty user OneDrive folder' -Do {
            Remove-Item -LiteralPath $userOneDrive -Recurse -Force -ErrorAction Stop
        }
    } else {
        Write-Step -Status Warn -Message "Left in place (contains files): $userOneDrive"
        Write-Step -Status Info -Message 'Review and move those files yourself, then delete the folder manually.'
    }
} else {
    Write-Step -Status Skip -Message "Not present: $userOneDrive"
}

# ===========================================================================
# 6. Write the permanent policy block
# ===========================================================================
Write-Host "`n[6/7] Writing permanent OneDrive block (Group Policy)..." -ForegroundColor White

$policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
Invoke-Change -Target $policyKey -Action 'Create policy key' -Do {
    if (-not (Test-Path -LiteralPath $policyKey)) {
        New-Item -Path $policyKey -Force -ErrorAction Stop | Out-Null
    }
}

# DisableFileSyncNGSC is the documented "Prevent the usage of OneDrive for file
# storage" policy and is what survives feature updates. DisableFileSync covers
# the legacy sync engine as well.
foreach ($pol in @('DisableFileSyncNGSC', 'DisableFileSync')) {
    Invoke-Change -Target "$policyKey\$pol" -Action 'Set policy DWORD = 1' -Do {
        New-ItemProperty -Path $policyKey -Name $pol -Value 1 `
            -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    }
}

# Stop NEW user profiles from auto-installing OneDrive by removing the setup
# stub from the Default user hive. The hive is loaded, edited, then unloaded.
$defaultHive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
if (Test-Path -LiteralPath $defaultHive) {
    Invoke-Change -Target 'Default user hive OneDriveSetup Run value' -Action 'Remove from new-profile template' -Do {
        $mountName = 'ClaudeOneDriveDefault'
        # reg.exe is used for load/unload; the PowerShell registry provider
        # cannot mount an offline hive.
        & reg.exe load "HKU\$mountName" "$defaultHive" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "reg load failed (exit $LASTEXITCODE)" }
        try {
            & reg.exe delete "HKU\$mountName\Software\Microsoft\Windows\CurrentVersion\Run" /v 'OneDriveSetup' /f 2>$null | Out-Null
            # A missing value is fine; it means nothing to remove.
        } finally {
            [gc]::Collect()
            Start-Sleep -Milliseconds 500
            & reg.exe unload "HKU\$mountName" | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "reg unload failed (exit $LASTEXITCODE) - hive may still be mounted" }
        }
    }
} else {
    Write-Step -Status Skip -Message "Default user hive not found: $defaultHive"
}

# ===========================================================================
# 7. Boot-time re-assert task + folder hardening
# ===========================================================================
Write-Host "`n[7/7] Installing boot-time re-assert task..." -ForegroundColor White

# Belt-and-suspenders: a feature update can occasionally clear policy keys.
# This SYSTEM task re-writes them at every boot. It runs an inline command and
# depends on no script file, so there is no writable-script-as-SYSTEM hole.
$taskName = 'Reassert-OneDrive-Block'

# Single-quoted registry paths so the only double quotes on the final command
# line are the outer -Command wrapper (nested double quotes would break the task).
$reassert = @(
    "New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Force | Out-Null;",
    "New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name DisableFileSyncNGSC -Value 1 -PropertyType DWord -Force | Out-Null;",
    "New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name DisableFileSync -Value 1 -PropertyType DWord -Force | Out-Null"
) -join ' '

Invoke-Change -Target $taskName -Action 'Register boot-time SYSTEM task' -Do {
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$reassert`""
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    # Replace any prior copy so re-running the script is idempotent.
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings `
        -Description 'Re-asserts the OneDrive machine-wide block after updates.' `
        -ErrorAction Stop | Out-Null
}

# Harden C:\Scripts because a SYSTEM-run task exists on this machine. Even though
# the task is inline, this folder is the standard home for admin scripts and a
# world-writable location invites privilege escalation.
$scriptsDir = Join-Path $env:SystemDrive 'Scripts'
Invoke-Change -Target $scriptsDir -Action 'Create and harden folder ACL' -Do {
    if (-not (Test-Path -LiteralPath $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force -ErrorAction Stop | Out-Null
    }
    & icacls.exe "$scriptsDir" /inheritance:r `
        /grant:r "Administrators:(OI)(CI)F" `
        /grant:r "SYSTEM:(OI)(CI)F" `
        /grant:r "Users:(OI)(CI)RX" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls failed (exit $LASTEXITCODE)" }
}

# ===========================================================================
# Summary
# ===========================================================================
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
if ($WhatIfPreference) {
    Write-Host " PREVIEW complete. No changes were made (-WhatIf)." -ForegroundColor Yellow
    Write-Host " Re-run without -WhatIf to apply." -ForegroundColor Yellow
} else {
    Write-Host " Done. Changes applied: $script:ChangeCount" -ForegroundColor Green
    Write-Host ""
    Write-Host " Restart File Explorer or sign out/in for the sidebar icon to clear." -ForegroundColor White
    Write-Host " Verify the block:  Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'" -ForegroundColor White
    Write-Host " Verify the task:   Get-ScheduledTask -TaskName 'Reassert-OneDrive-Block'" -ForegroundColor White
}
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

exit 0
