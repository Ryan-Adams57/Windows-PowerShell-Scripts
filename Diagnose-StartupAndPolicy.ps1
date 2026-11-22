<#
    Diagnose-StartupAndPolicy.ps1

    SCRIPT HIGHLIGHTS
    - Read-only. Makes no changes to the system. Safe to run at any time.
    - Finds what triggers the "managed by your organization" banner in Chrome and Edge:
      names the exact policy values and whether they come from local registry or the cloud.
    - Lists everything that launches at logon or boot (scheduled tasks, Run keys, Startup folders).
    - Flags scheduled tasks whose target .ps1/.bat/.cmd no longer exists. That is the usual
      cause of a stray CMD or PowerShell window popping up on every restart.
    - Reports whether the device is actually Azure AD joined or MDM enrolled, so you can tell
      real management apart from a leftover policy key.
    - Writes a timestamped text report and can open it with -OpenReport.

    REQUIREMENTS
    - Windows PowerShell 5.1 or later. No external modules.
    - Run as Administrator for complete results (HKLM reads and some task details need elevation).

    PARAMETERS
    - ExportPath : full path for the report file. Defaults to a timestamped file on the Desktop.
    - OpenReport : switch. Opens the finished report in Notepad. Off by default (automation-safe).

    DISCLAIMER
    - Provided as-is with no warranty. Read-only by design: it reports, it does not remediate.
      Review every finding before acting on it. The browser banner and the PowerShell 5.1
      "install the latest" notice are not bugs; see the README for what each one means.

    Last Updated: 2026-11-21
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$OpenReport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Setup: resolve a default report path and prepare the in-memory report buffer
# ---------------------------------------------------------------------------
if (-not $ExportPath) {
    try {
        # GetFolderPath respects OneDrive Desktop redirection; USERPROFILE does not.
        $desktop = [Environment]::GetFolderPath('Desktop')
        if (-not $desktop) { $desktop = $env:USERPROFILE }
    }
    catch {
        $desktop = $env:USERPROFILE
    }
    $stamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
    $ExportPath = Join-Path $desktop ("StartupPolicyReport_{0}.txt" -f $stamp)
}

# Collects every printed line so the same content lands in the report file.
$report = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param(
        [string]$Text,
        [string]$Color
    )
    if ($Color) { Write-Host $Text -ForegroundColor $Color }
    else        { Write-Host $Text }
    $report.Add($Text)
}

# Dumps every value and subkey under a registry path, or notes its absence.
function Show-PolicyKey {
    param(
        [string]$Path,
        [string]$Label
    )
    if (Test-Path $Path) {
        Add-Line ("[{0}] {1}" -f $Label, $Path) 'Yellow'
        try {
            $item  = Get-ItemProperty -Path $Path -ErrorAction Stop
            $props = $item.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }
            if ($props) {
                foreach ($p in $props) { Add-Line ("    {0} = {1}" -f $p.Name, $p.Value) }
            }
            else {
                Add-Line "    (key exists with no values - its mere presence can trigger the banner)"
            }
            $subs = Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue
            foreach ($s in $subs) { Add-Line ("    SUBKEY: {0}" -f $s.PSChildName) }
        }
        catch {
            Add-Line ("    ERROR reading key: {0}" -f $_.Exception.Message) 'Red'
        }
    }
    else {
        Add-Line ("[{0}] {1} -> not present" -f $Label, $Path)
    }
}

# Pulls the first .ps1/.bat/.cmd path out of a task's command line, if any.
function Resolve-TaskFile {
    param([string]$Full)
    $m = [regex]::Match($Full, '"([^"]+\.(?:ps1|bat|cmd))"')
    if ($m.Success) { return $m.Groups[1].Value }
    $m = [regex]::Match($Full, '([A-Za-z]:\\[^\s"]+\.(?:ps1|bat|cmd))')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

# ---------------------------------------------------------------------------
# Header + elevation check
# ---------------------------------------------------------------------------
Add-Line ("Startup and Policy Diagnostic  -  {0}" -f (Get-Date)) 'Cyan'
Add-Line ("Computer: {0}   User: {1}" -f $env:COMPUTERNAME, $env:USERNAME)
Add-Line ""

try {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
catch {
    $isAdmin = $false
}
if (-not $isAdmin) {
    Add-Line "WARNING: not elevated. Some HKLM keys and task details may be incomplete. Re-run as Administrator for a full picture." 'Yellow'
    Add-Line ""
}

$totalSteps = 7
$step       = 0

# ---------------------------------------------------------------------------
# 1. Browser policy keys (the "managed by your organization" source)
# ---------------------------------------------------------------------------
$step++; Write-Progress -Activity "Diagnosing" -Status "Browser policies" -PercentComplete (($step / $totalSteps) * 100)
Add-Line "===== 1. BROWSER POLICY KEYS =====" 'Cyan'
try {
    Show-PolicyKey 'HKLM:\SOFTWARE\Policies\Google\Chrome'              'Chrome HKLM'
    Show-PolicyKey 'HKLM:\SOFTWARE\WOW6432Node\Policies\Google\Chrome'  'Chrome HKLM x86'
    Show-PolicyKey 'HKCU:\SOFTWARE\Policies\Google\Chrome'              'Chrome HKCU'
    Show-PolicyKey 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'             'Edge HKLM'
    Show-PolicyKey 'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Edge' 'Edge HKLM x86'
    Show-PolicyKey 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'             'Edge HKCU'
}
catch {
    Add-Line ("  ERROR in section 1: {0}" -f $_.Exception.Message) 'Red'
}
Add-Line ""

# ---------------------------------------------------------------------------
# 2. Chrome cloud-management enrollment token (banner with empty policy page)
# ---------------------------------------------------------------------------
$step++; Write-Progress -Activity "Diagnosing" -Status "Cloud enrollment" -PercentComplete (($step / $totalSteps) * 100)
Add-Line "===== 2. CHROME CLOUD ENROLLMENT TOKEN =====" 'Cyan'
try {
    $chromeKey = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Google\Chrome' -ErrorAction SilentlyContinue
    $token     = $null
    if ($chromeKey -and ($chromeKey.PSObject.Properties.Name -contains 'CloudManagementEnrollmentToken')) {
        $token = $chromeKey.CloudManagementEnrollmentToken
    }
    if ($token) { Add-Line ("  CloudManagementEnrollmentToken present: {0}" -f $token) 'Yellow' }
    else        { Add-Line "  (no cloud enrollment token)" }
}
catch {
    Add-Line ("  ERROR in section 2: {0}" -f $_.Exception.Message) 'Red'
}
Add-Line ""

# ---------------------------------------------------------------------------
# 3. Real device management (Azure AD join / MDM)
# ---------------------------------------------------------------------------
$step++; Write-Progress -Activity "Diagnosing" -Status "Device enrollment" -PercentComplete (($step / $totalSteps) * 100)
Add-Line "===== 3. DEVICE ENROLLMENT (real management vs leftover) =====" 'Cyan'
try {
    $ds = & dsregcmd /status 2>$null | Select-String 'AzureAdJoined|DomainJoined|WorkplaceJoined|TenantName|MdmUrl'
    if ($ds) { foreach ($line in $ds) { Add-Line ("  {0}" -f $line.ToString().Trim()) } }
    else     { Add-Line "  (dsregcmd returned no join/MDM lines)" }
}
catch {
    Add-Line ("  ERROR running dsregcmd: {0}" -f $_.Exception.Message) 'Red'
}
Add-Line ""

# ---------------------------------------------------------------------------
# 4. Scheduled tasks that launch scripts/consoles, with missing-target flag
# ---------------------------------------------------------------------------
$step++; Write-Progress -Activity "Diagnosing" -Status "Scheduled tasks" -PercentComplete (($step / $totalSteps) * 100)
Add-Line "===== 4. SCHEDULED TASKS LAUNCHING SCRIPTS / CONSOLES =====" 'Cyan'
$missingTargets = @()
try {
    $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    foreach ($t in $allTasks) {
        $exec   = ($t.Actions | ForEach-Object { $_.Execute })   -join ' '
        $argStr = ($t.Actions | ForEach-Object { $_.Arguments }) -join ' '
        $full   = ("{0} {1}" -f $exec, $argStr).Trim()
        if ($full -match 'cmd|\.bat|\.cmd|powershell|pwsh|\.ps1|wscript|cscript') {
            $file   = Resolve-TaskFile $full
            if ($file) { $exists = Test-Path $file } else { $exists = 'n/a' }

            $color = $null
            $flag  = ''
            if ($exists -eq $false) {
                $color = 'Red'
                $flag  = '   <-- TARGET MISSING (likely restart-popup source)'
                $missingTargets += $t.TaskName
            }
            Add-Line ("  {0} [{1}] user={2} state={3} exists={4}{5}" -f `
                $t.TaskName, $t.TaskPath, $t.Principal.UserId, $t.State, $exists, $flag) $color
            if ($file) { Add-Line ("      target: {0}" -f $file) }
        }
    }
    if (-not $missingTargets) { Add-Line "  (no task points at a missing script)" 'Green' }
}
catch {
    Add-Line ("  ERROR in section 4: {0}" -f $_.Exception.Message) 'Red'
}
Add-Line ""

# ---------------------------------------------------------------------------
# 5. Run keys (HKLM + HKCU)
# ---------------------------------------------------------------------------
$step++; Write-Progress -Activity "Diagnosing" -Status "Run keys" -PercentComplete (($step / $totalSteps) * 100)
Add-Line "===== 5. RUN KEYS =====" 'Cyan'
$runKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
try {
    foreach ($rk in $runKeys) {
        if (Test-Path $rk) {
            Add-Line ("[{0}]" -f $rk) 'Yellow'
            $item  = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
            $props = $item.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }
            foreach ($p in $props) { Add-Line ("   {0} = {1}" -f $p.Name, $p.Value) }
        }
    }
}
catch {
    Add-Line ("  ERROR in section 5: {0}" -f $_.Exception.Message) 'Red'
}
Add-Line ""

# ---------------------------------------------------------------------------
# 6. Startup folders
# ---------------------------------------------------------------------------
$step++; Write-Progress -Activity "Diagnosing" -Status "Startup folders" -PercentComplete (($step / $totalSteps) * 100)
Add-Line "===== 6. STARTUP FOLDERS =====" 'Cyan'
$startupPaths = @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
    'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
)
try {
    $found = $false
    foreach ($sp in $startupPaths) {
        $items = Get-ChildItem -Path $sp -ErrorAction SilentlyContinue
        foreach ($i in $items) { Add-Line ("  {0}" -f $i.FullName); $found = $true }
    }
    if (-not $found) { Add-Line "  (startup folders empty)" }
}
catch {
    Add-Line ("  ERROR in section 6: {0}" -f $_.Exception.Message) 'Red'
}
Add-Line ""

# ---------------------------------------------------------------------------
# 7. Non-Microsoft services pointing at scripts
# ---------------------------------------------------------------------------
$step++; Write-Progress -Activity "Diagnosing" -Status "Services" -PercentComplete (($step / $totalSteps) * 100)
Add-Line "===== 7. SERVICES REFERENCING SCRIPTS =====" 'Cyan'
try {
    $svc = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
           Where-Object { $_.PathName -match '\.bat|\.ps1|\.cmd|debloat|tweak' }
    if ($svc) {
        foreach ($s in $svc) { Add-Line ("  {0}  [{1}]  {2}" -f $s.Name, $s.StartMode, $s.PathName) }
    }
    else {
        Add-Line "  (no service launches a script)" 'Green'
    }
}
catch {
    Add-Line ("  ERROR in section 7: {0}" -f $_.Exception.Message) 'Red'
}
Add-Line ""
Write-Progress -Activity "Diagnosing" -Completed

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Add-Line "===== SUMMARY =====" 'Cyan'
if ($missingTargets) {
    Add-Line ("  {0} task(s) point at a missing script - the likely restart-popup cause:" -f $missingTargets.Count) 'Red'
    foreach ($m in $missingTargets) { Add-Line ("    - {0}" -f $m) 'Red' }
    Add-Line "  Fix: repoint the task at the real script, or remove the task if it is dead."
}
else {
    Add-Line "  No dead scheduled-task targets found." 'Green'
}
Add-Line ""

# ---------------------------------------------------------------------------
# Write report file + optional open
# ---------------------------------------------------------------------------
try {
    $report | Set-Content -Path $ExportPath -Encoding UTF8
    Add-Line ("Report written to: {0}" -f $ExportPath) 'Green'
}
catch {
    Add-Line ("ERROR writing report: {0}" -f $_.Exception.Message) 'Red'
    exit 1
}

if ($OpenReport) {
    try   { Start-Process notepad.exe -ArgumentList $ExportPath }
    catch { Add-Line ("Could not open report: {0}" -f $_.Exception.Message) 'Yellow' }
}

exit 0
