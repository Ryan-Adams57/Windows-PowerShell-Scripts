<#
.SYNOPSIS
    PC Toolkit (CORPORATE) - maintenance & diagnostics menu for managed/domain machines.
.NOTES
    Windows PowerShell 5.1 or PowerShell 7+.
    Self-elevates to Administrator. Logs every session to a transcript for audit.
    Deliberately omits consumer-only and policy-sensitive actions
    (Wi-Fi password export, full network/Winsock reset, battery report).
#>

#Requires -Version 5.1

# ---------------------------------------------------------------------------
# Self-elevate to Administrator
# ---------------------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
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
            Write-Host "Elevation cancelled or failed. Some options will not work." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
        exit
    } else {
        Write-Host "WARNING: Not running as Administrator. Several options will fail." -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

# ---------------------------------------------------------------------------
# Audit logging (transcript)
# ---------------------------------------------------------------------------
$logDir = Join-Path $env:ProgramData "PC-Toolkit-Logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir ("toolkit_{0}_{1:yyyyMMdd_HHmmss}.log" -f $env:USERNAME, (Get-Date))
try { Start-Transcript -Path $logFile -Append -ErrorAction Stop | Out-Null } catch {}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Pause-Return {
    Write-Host ""
    Read-Host "Press Enter to return to the menu" | Out-Null
}

function Confirm-Action {
    param([string]$Message)
    $answer = Read-Host "$Message (Y/N)"
    return ($answer -match '^(y|yes)$')
}

# ---------------------------------------------------------------------------
# Management-state detection
# Authoritative source is `dsregcmd /status`, NOT Win32_ComputerSystem.PartOfDomain
# and NOT PolicyManager provider GUIDs. PartOfDomain misses Entra (Azure AD) join,
# and the provider GUIDs exist on every stock Windows 11 box.
# ---------------------------------------------------------------------------
function Get-ManagementState {
    # dsregcmd runs in the user context and needs no admin; returns plain text.
    $raw = cmd /c "dsregcmd /status" 2>$null
    $read = {
        param([string]$Key)
        $m = $raw | Select-String -Pattern ("^\s*{0}\s*:\s*(\S+)" -f [regex]::Escape($Key))
        if ($m) { $m.Matches[0].Groups[1].Value } else { "Unknown" }
    }
    [PSCustomObject]@{
        AzureAdJoined    = (& $read 'AzureAdJoined')     # Entra (Azure AD) joined
        EnterpriseJoined = (& $read 'EnterpriseJoined')  # on-prem Enterprise (DRS) joined
        DomainJoined     = (& $read 'DomainJoined')      # classic AD domain joined
    }
}

# True if the machine is managed by any of the three join types.
function Test-IsManaged {
    $s = Get-ManagementState
    return ($s.AzureAdJoined -eq 'YES' -or $s.EnterpriseJoined -eq 'YES' -or $s.DomainJoined -eq 'YES')
}

# ---------------------------------------------------------------------------
# 1. Clean Temp Files (conservative: user + machine temp only)
# ---------------------------------------------------------------------------
function Invoke-CleanTemp {
    $paths = @("$env:TEMP", "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
    $freedBytes = 0
    foreach ($p in ($paths | Select-Object -Unique)) {
        if (Test-Path $p) {
            $before = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
                       Measure-Object -Property Length -Sum).Sum
            Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            $after = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
                      Measure-Object -Property Length -Sum).Sum
            $freedBytes += [Math]::Max(0, ($before - $after))
        }
    }
    Write-Host ("Temp folders cleaned. Freed approximately {0} MB." -f [Math]::Round($freedBytes/1MB,2)) -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Flush DNS (+ release/renew, safe on managed machines)
# ---------------------------------------------------------------------------
function Invoke-FlushDNS {
    ipconfig /flushdns
    if (Confirm-Action "Also release & renew the DHCP lease?") {
        ipconfig /release
        ipconfig /renew
    }
    Write-Host "DNS cache flushed." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3. Show IP / Network Info
# ---------------------------------------------------------------------------
function Show-IPInfo {
    Get-NetIPConfiguration | Format-List
    Write-Host "--- ipconfig /all ---" -ForegroundColor DarkGray
    ipconfig /all
}

# ---------------------------------------------------------------------------
# 4. System Info (domain-aware)
# ---------------------------------------------------------------------------
function Show-SystemInfo {
    $os  = Get-CimInstance Win32_OperatingSystem
    $cs  = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $mg  = Get-ManagementState   # join state from dsregcmd, not PartOfDomain
    [PSCustomObject]@{
        ComputerName     = $cs.Name
        DnsDomain        = $cs.Domain          # display only; not used to judge management
        AzureAdJoined    = $mg.AzureAdJoined
        EnterpriseJoined = $mg.EnterpriseJoined
        DomainJoined     = $mg.DomainJoined
        LoggedOnUser     = $cs.UserName
        Manufacturer     = $cs.Manufacturer
        Model            = $cs.Model
        OS               = $os.Caption
        Build            = $os.BuildNumber
        Architecture     = $os.OSArchitecture
        CPU              = $cpu.Name
        Cores            = $cpu.NumberOfCores
        RAM_GB           = [Math]::Round($cs.TotalPhysicalMemory/1GB,2)
        LastBoot         = $os.LastBootUpTime
    } | Format-List
}

# ---------------------------------------------------------------------------
# 5. Disk Check (CHKDSK)
# ---------------------------------------------------------------------------
function Invoke-DiskCheck {
    $drive = Read-Host "Drive letter to check (default C)"
    if ([string]::IsNullOrWhiteSpace($drive)) { $drive = "C" }
    $drive = $drive.TrimEnd(':').ToUpper()
    Write-Host "Running read-only scan on ${drive}: ..." -ForegroundColor Yellow
    chkdsk "${drive}:"
    Write-Host ""
    if (Confirm-Action "Run a REPAIR pass (chkdsk /F)? On the system drive this schedules a check at next reboot") {
        chkdsk "${drive}:" /F
        Write-Host "If this is the system/boot drive, repair runs on next restart." -ForegroundColor Cyan
    }
}

# ---------------------------------------------------------------------------
# 6. Repair System Files (SFC + DISM)
# ---------------------------------------------------------------------------
function Invoke-SFC {
    Write-Host "Running System File Checker. This can take several minutes..." -ForegroundColor Yellow
    sfc /scannow
    Write-Host ""
    if (Confirm-Action "Also run DISM RestoreHealth?") {
        DISM /Online /Cleanup-Image /RestoreHealth
    }
}

# ---------------------------------------------------------------------------
# 7. Restart Explorer
# ---------------------------------------------------------------------------
function Restart-Explorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
    Write-Host "Explorer restarted." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 8. Force Group Policy Update
# ---------------------------------------------------------------------------
function Invoke-GpUpdate {
    $mg = Get-ManagementState
    $managed = ($mg.AzureAdJoined -eq 'YES' -or $mg.EnterpriseJoined -eq 'YES' -or $mg.DomainJoined -eq 'YES')
    if (-not $managed) {
        # Graceful bail: on a standalone machine there is no domain/Entra GPO to pull.
        Write-Host "This machine is not domain- or Entra-joined." -ForegroundColor Yellow
        Write-Host ("  AzureAdJoined={0}  DomainJoined={1}  EnterpriseJoined={2}" -f `
            $mg.AzureAdJoined, $mg.DomainJoined, $mg.EnterpriseJoined) -ForegroundColor DarkGray
        Write-Host "gpupdate would only refresh LOCAL policy; there is no domain policy to retrieve." -ForegroundColor Yellow
        if (-not (Confirm-Action "Refresh local policy anyway?")) {
            Write-Host "Skipped." -ForegroundColor DarkGray
            return
        }
    }
    Write-Host "Forcing a Group Policy refresh (gpupdate /force)..." -ForegroundColor Yellow
    gpupdate /force
    Write-Host ""
    Write-Host "Some policies (software install, folder redirection) only apply at next logon/reboot." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# 9. Show Running Tasks
# ---------------------------------------------------------------------------
function Show-RunningTasks {
    Get-Process |
        Sort-Object -Property WS -Descending |
        Select-Object -First 30 Name, Id,
            @{N='CPU(s)';E={[Math]::Round($_.CPU,1)}},
            @{N='RAM(MB)';E={[Math]::Round($_.WS/1MB,1)}} |
        Format-Table -AutoSize
    Write-Host "(Top 30 processes by memory.)" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 10. Show Mapped Network Drives
# ---------------------------------------------------------------------------
function Show-MappedDrives {
    $maps = Get-CimInstance Win32_MappedLogicalDisk -ErrorAction SilentlyContinue
    if ($maps) {
        $maps | Select-Object DeviceID, ProviderName,
            @{N='Free(GB)';E={[Math]::Round($_.FreeSpace/1GB,1)}} |
            Format-Table -AutoSize
    } else {
        Write-Host "No mapped network drives found." -ForegroundColor DarkGray
    }
    Write-Host "--- net use ---" -ForegroundColor DarkGray
    net use
}

# ---------------------------------------------------------------------------
# 11. Recent System Errors (Event Log)
# ---------------------------------------------------------------------------
function Show-RecentErrors {
    Write-Host "Most recent 20 System-log Errors/Warnings:" -ForegroundColor Cyan
    Get-WinEvent -FilterHashtable @{ LogName='System'; Level=1,2,3 } -MaxEvents 20 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName,
            @{N='Message';E={ ($_.Message -split "`n")[0] }} |
        Format-Table -AutoSize -Wrap
}

# ---------------------------------------------------------------------------
# 12. Disk Usage
# ---------------------------------------------------------------------------
function Show-DiskUsage {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{N='Size(GB)';E={[Math]::Round($_.Size/1GB,1)}},
            @{N='Free(GB)';E={[Math]::Round($_.FreeSpace/1GB,1)}},
            @{N='Free(%)';E={ if($_.Size){[Math]::Round(($_.FreeSpace/$_.Size)*100,1)}else{0} }} |
        Format-Table -AutoSize
}

# ---------------------------------------------------------------------------
# 13. Windows Update / Pending Reboot Check
# ---------------------------------------------------------------------------
function Show-UpdateStatus {
    Write-Host "Pending-reboot indicators:" -ForegroundColor Cyan
    $cbs = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $wu  = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    $pfr = $null -ne (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    [PSCustomObject]@{
        ComponentServicingPending = $cbs
        WindowsUpdatePending      = $wu
        PendingFileRename         = $pfr
        RebootRecommended         = ($cbs -or $wu -or $pfr)
    } | Format-List

    if (Confirm-Action "Check the Windows Update service status?") {
        Get-Service wuauserv | Select-Object Status, Name, DisplayName | Format-Table -AutoSize
    }
}

# ---------------------------------------------------------------------------
# 14-16. Launch consoles
# ---------------------------------------------------------------------------
# (handled inline in switch)

# ---------------------------------------------------------------------------
# 17. Generate Diagnostic Report (to file)
# ---------------------------------------------------------------------------
function New-DiagnosticReport {
    $report = Join-Path $logDir ("diag_{0}_{1:yyyyMMdd_HHmmss}.txt" -f $env:COMPUTERNAME, (Get-Date))
    "ULTIMATE PC TOOLKIT - DIAGNOSTIC REPORT"            | Out-File $report
    "Generated: $(Get-Date)"                              | Out-File $report -Append
    "Machine:   $env:COMPUTERNAME  User: $env:USERNAME"   | Out-File $report -Append
    "`n=== SYSTEM ==="                                    | Out-File $report -Append
    Get-ComputerInfo -Property CsName, OsName, OsVersion, WindowsBuildLabEx, CsDomain, CsManufacturer, CsModel -ErrorAction SilentlyContinue |
        Out-File $report -Append
    "`n=== DISKS ==="                                     | Out-File $report -Append
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{N='Size(GB)';E={[Math]::Round($_.Size/1GB,1)}},
            @{N='Free(GB)';E={[Math]::Round($_.FreeSpace/1GB,1)}} |
        Out-File $report -Append
    "`n=== NETWORK ==="                                   | Out-File $report -Append
    Get-NetIPConfiguration | Out-File $report -Append
    "`n=== RECENT SYSTEM ERRORS ==="                      | Out-File $report -Append
    Get-WinEvent -FilterHashtable @{ LogName='System'; Level=1,2 } -MaxEvents 15 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, ProviderName, Message | Out-File $report -Append
    Write-Host "Report saved to: $report" -ForegroundColor Green
    if (Confirm-Action "Open it now?") { Start-Process notepad.exe $report }
}

# ---------------------------------------------------------------------------
# 18 / 19. Restart & Shutdown
# ---------------------------------------------------------------------------
function Restart-PC {
    Write-Host "On a shared/corporate machine, confirm no one else is signed in." -ForegroundColor Yellow
    if (Confirm-Action "Restart this PC now?") {
        shutdown /r /t 10 /c "Restart initiated via PC Toolkit"
        Write-Host "Restarting in 10s. Abort with: shutdown /a" -ForegroundColor Cyan
    }
}

function Shutdown-PC {
    Write-Host "On a shared/corporate machine, confirm no one else is signed in." -ForegroundColor Yellow
    if (Confirm-Action "Shut down this PC now?") {
        shutdown /s /t 10 /c "Shutdown initiated via PC Toolkit"
        Write-Host "Shutting down in 10s. Abort with: shutdown /a" -ForegroundColor Cyan
    }
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
function Show-Menu {
    Clear-Host
    $line = ('=' * 44)
    Write-Host $line -ForegroundColor Cyan
    Write-Host "          PC TOOLKIT  -  CORPORATE" -ForegroundColor White
    Write-Host "        (session logged to $logDir)" -ForegroundColor DarkGray
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  1.  Clean Temp Files"
    Write-Host "  2.  Flush DNS"
    Write-Host "  3.  Show IP / Network Info"
    Write-Host "  4.  System Info (domain-aware)"
    Write-Host "  5.  Disk Check (CHKDSK)"
    Write-Host "  6.  Repair System Files (SFC + DISM)"
    Write-Host "  7.  Restart Explorer"
    Write-Host "  8.  Force Group Policy Update"
    Write-Host "  9.  Show Running Tasks"
    Write-Host "  10. Show Mapped Network Drives"
    Write-Host "  11. Recent System Errors (Event Log)"
    Write-Host "  12. Disk Usage"
    Write-Host "  13. Windows Update / Pending Reboot"
    Write-Host "  14. Open Task Manager"
    Write-Host "  15. Open Services"
    Write-Host "  16. Open Device Manager"
    Write-Host "  17. Generate Diagnostic Report"
    Write-Host "  18. Restart PC"
    Write-Host "  19. Shutdown PC"
    Write-Host "  20. Exit"
    Write-Host $line -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
do {
    Show-Menu
    $choice = Read-Host "Select an option (1-20)"
    Write-Host ""

    switch ($choice) {
        '1'  { Invoke-CleanTemp;       Pause-Return }
        '2'  { Invoke-FlushDNS;        Pause-Return }
        '3'  { Show-IPInfo;            Pause-Return }
        '4'  { Show-SystemInfo;        Pause-Return }
        '5'  { Invoke-DiskCheck;       Pause-Return }
        '6'  { Invoke-SFC;             Pause-Return }
        '7'  { Restart-Explorer;       Pause-Return }
        '8'  { Invoke-GpUpdate;        Pause-Return }
        '9'  { Show-RunningTasks;      Pause-Return }
        '10' { Show-MappedDrives;      Pause-Return }
        '11' { Show-RecentErrors;      Pause-Return }
        '12' { Show-DiskUsage;         Pause-Return }
        '13' { Show-UpdateStatus;      Pause-Return }
        '14' { Start-Process taskmgr.exe }
        '15' { Start-Process services.msc }
        '16' { Start-Process devmgmt.msc }
        '17' { New-DiagnosticReport;   Pause-Return }
        '18' { Restart-PC;             Pause-Return }
        '19' { Shutdown-PC;            Pause-Return }
        '20' { Write-Host "Exiting. Session log: $logFile" -ForegroundColor Green }
        default {
            Write-Host "Invalid selection: '$choice'. Choose 1-20." -ForegroundColor Red
            Pause-Return
        }
    }
} while ($choice -ne '20')

try { Stop-Transcript | Out-Null } catch {}
