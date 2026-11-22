<#
.SYNOPSIS
    Ultimate PC Toolkit (PERSONAL) - interactive Windows maintenance & diagnostics menu.
.NOTES
    Run in Windows PowerShell 5.1 or PowerShell 7+.
    The script self-elevates to Administrator (several options require it).
    If you paste it into a console instead of running the .ps1, elevation is skipped.
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
        Write-Host "WARNING: Not running as Administrator. Options 5, 6, 8, 17 may fail." -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

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
# 1. Clean Temp Files
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
    $freedMB = [Math]::Round($freedBytes / 1MB, 2)
    Write-Host "Temp folders cleaned. Freed approximately $freedMB MB." -ForegroundColor Green
    Write-Host "(Files in use by running programs are skipped automatically.)" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 2. Flush DNS
# ---------------------------------------------------------------------------
function Invoke-FlushDNS {
    ipconfig /flushdns
    Write-Host "DNS resolver cache flushed." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3. Show IP Info
# ---------------------------------------------------------------------------
function Show-IPInfo {
    Get-NetIPConfiguration | Format-List
    Write-Host "--- Detailed (ipconfig /all) ---" -ForegroundColor DarkGray
    ipconfig /all
}

# ---------------------------------------------------------------------------
# 4. System Info
# ---------------------------------------------------------------------------
function Show-SystemInfo {
    $os  = Get-CimInstance Win32_OperatingSystem
    $cs  = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ramGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    [PSCustomObject]@{
        ComputerName = $cs.Name
        Manufacturer = $cs.Manufacturer
        Model        = $cs.Model
        OS           = $os.Caption
        Version      = $os.Version
        Build        = $os.BuildNumber
        Architecture = $os.OSArchitecture
        CPU          = $cpu.Name
        Cores        = $cpu.NumberOfCores
        LogicalCPUs  = $cpu.NumberOfLogicalProcessors
        RAM_GB       = $ramGB
        LastBoot     = $os.LastBootUpTime
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
    if (Confirm-Action "Run a REPAIR pass (chkdsk /F)? On the system drive this only schedules a check at next reboot") {
        chkdsk "${drive}:" /F
        Write-Host "If this is your system/boot drive, the repair will run on next restart." -ForegroundColor Cyan
    }
}

# ---------------------------------------------------------------------------
# 6. Repair System Files (SFC)
# ---------------------------------------------------------------------------
function Invoke-SFC {
    Write-Host "Running System File Checker. This can take several minutes..." -ForegroundColor Yellow
    sfc /scannow
    Write-Host ""
    if (Confirm-Action "Also run DISM RestoreHealth (deeper repair of the component store)?") {
        DISM /Online /Cleanup-Image /RestoreHealth
    }
}

# ---------------------------------------------------------------------------
# 7. Restart Explorer
# ---------------------------------------------------------------------------
function Restart-Explorer {
    Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
    Write-Host "Explorer restarted." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 8. Network Reset
# ---------------------------------------------------------------------------
function Invoke-NetworkReset {
    Write-Host "This resets Winsock + TCP/IP and releases/renews your IP." -ForegroundColor Yellow
    Write-Host "You will lose connectivity briefly and a REBOOT is required to finish." -ForegroundColor Yellow
    if (-not (Confirm-Action "Proceed with network reset?")) {
        Write-Host "Cancelled." -ForegroundColor DarkGray
        return
    }
    netsh winsock reset
    netsh int ip reset
    ipconfig /release
    ipconfig /renew
    ipconfig /flushdns
    Write-Host "Network stack reset. Restart the PC to complete the process." -ForegroundColor Cyan
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
    Write-Host "(Top 30 processes by memory usage.)" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 10. Kill Chrome
# ---------------------------------------------------------------------------
function Kill-Chrome {
    $procs = Get-Process -Name chrome -ErrorAction SilentlyContinue
    if (-not $procs) {
        Write-Host "Chrome is not running." -ForegroundColor DarkGray
        return
    }
    Write-Host "Found $($procs.Count) Chrome process(es). This will discard unsaved tabs/forms." -ForegroundColor Yellow
    if (Confirm-Action "Force-close Chrome?") {
        $procs | Stop-Process -Force
        Write-Host "Chrome terminated." -ForegroundColor Green
    } else {
        Write-Host "Cancelled." -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# 11. Battery Report
# ---------------------------------------------------------------------------
function Get-BatteryReport {
    $out = Join-Path $env:USERPROFILE "Desktop\battery-report.html"
    powercfg /batteryreport /output "$out" | Out-Null
    if (Test-Path $out) {
        Write-Host "Battery report saved to: $out" -ForegroundColor Green
        if (Confirm-Action "Open it now?") { Start-Process $out }
    } else {
        Write-Host "Could not generate a battery report (no battery, or desktop PC)." -ForegroundColor Red
    }
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
# 17. Show Wi-Fi Passwords
# ---------------------------------------------------------------------------
function Show-WiFiPasswords {
    Write-Host "Saved Wi-Fi profiles on THIS machine:" -ForegroundColor Cyan
    $profilesOutput = netsh wlan show profiles
    $names = $profilesOutput |
        Select-String "All User Profile\s*:\s*(.+)$" |
        ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }

    if (-not $names) {
        Write-Host "No saved Wi-Fi profiles found." -ForegroundColor DarkGray
        return
    }

    $results = foreach ($name in $names) {
        $detail = netsh wlan show profile name="$name" key=clear
        $keyLine = $detail | Select-String "Key Content\s*:\s*(.+)$"
        $pw = if ($keyLine) { $keyLine.Matches[0].Groups[1].Value.Trim() } else { "(none / open network)" }
        [PSCustomObject]@{ SSID = $name; Password = $pw }
    }
    $results | Format-Table -AutoSize
    Write-Host "(Shows only networks already saved on this PC.)" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 18 / 19. Restart & Shutdown
# ---------------------------------------------------------------------------
function Restart-PC {
    if (Confirm-Action "Restart this PC now?") {
        Write-Host "Restarting in 5 seconds... (close this window to abort: shutdown /a)" -ForegroundColor Yellow
        shutdown /r /t 5
    }
}

function Shutdown-PC {
    if (Confirm-Action "Shut down this PC now?") {
        Write-Host "Shutting down in 5 seconds... (abort with: shutdown /a)" -ForegroundColor Yellow
        shutdown /s /t 5
    }
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
function Show-Menu {
    Clear-Host
    $line = ('=' * 40)
    Write-Host $line -ForegroundColor Cyan
    Write-Host "             ULTIMATE PC TOOLKIT" -ForegroundColor White
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  1.  Clean Temp Files"
    Write-Host "  2.  Flush DNS"
    Write-Host "  3.  Show IP Info"
    Write-Host "  4.  System Info"
    Write-Host "  5.  Disk Check (CHKDSK)"
    Write-Host "  6.  Repair System Files (SFC)"
    Write-Host "  7.  Restart Explorer"
    Write-Host "  8.  Network Reset"
    Write-Host "  9.  Show Running Tasks"
    Write-Host "  10. Kill Chrome"
    Write-Host "  11. Battery Report"
    Write-Host "  12. Disk Usage"
    Write-Host "  13. Open Control Panel"
    Write-Host "  14. Open Task Manager"
    Write-Host "  15. Open Services"
    Write-Host "  16. Open Device Manager"
    Write-Host "  17. Show Wi-Fi Passwords"
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
        '1'  { Invoke-CleanTemp;     Pause-Return }
        '2'  { Invoke-FlushDNS;      Pause-Return }
        '3'  { Show-IPInfo;          Pause-Return }
        '4'  { Show-SystemInfo;      Pause-Return }
        '5'  { Invoke-DiskCheck;     Pause-Return }
        '6'  { Invoke-SFC;           Pause-Return }
        '7'  { Restart-Explorer;     Pause-Return }
        '8'  { Invoke-NetworkReset;  Pause-Return }
        '9'  { Show-RunningTasks;    Pause-Return }
        '10' { Kill-Chrome;          Pause-Return }
        '11' { Get-BatteryReport;    Pause-Return }
        '12' { Show-DiskUsage;       Pause-Return }
        '13' { Start-Process control.exe }
        '14' { Start-Process taskmgr.exe }
        '15' { Start-Process services.msc }
        '16' { Start-Process devmgmt.msc }
        '17' { Show-WiFiPasswords;   Pause-Return }
        '18' { Restart-PC;           Pause-Return }
        '19' { Shutdown-PC;          Pause-Return }
        '20' { Write-Host "Goodbye." -ForegroundColor Green }
        default {
            Write-Host "Invalid selection: '$choice'. Choose 1-20." -ForegroundColor Red
            Pause-Return
        }
    }
} while ($choice -ne '20')
