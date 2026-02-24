<#
.SYNOPSIS
    Custom Super God Mode Lite
.DESCRIPTION
    Creates a folder on the Desktop with categorized shortcuts to Windows shell folders, Control Panel items, and Settings URIs.
    This is inspired by the broader "Super God Mode" script idea but is simplified.

    Requires Windows PowerShell (5.1 or later).
#>

# Ensure script runs with admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as an Administrator."
    return
}

# Resolve Desktop Directory
$desktop = [Environment]::GetFolderPath("Desktop")
$outputRoot = Join-Path $desktop "SuperGodMode-Lite"

# Create Output Root
if (-not (Test-Path $outputRoot)) { New-Item -Path $outputRoot -ItemType Directory | Out-Null }

Write-Host "Creating Super God Mode Lite structure..." -ForegroundColor Cyan

# 1) Shell Folder Shortcuts
$shellFolderTargets = @{
    "AppData"     = [Environment]::GetFolderPath("ApplicationData")
    "ProgramFiles"= [Environment]::GetFolderPath("ProgramFiles")
    "SystemRoot"  = $env:SystemRoot
    "UserProfile" = [Environment]::GetFolderPath("UserProfile")
}

$sfDir = Join-Path $outputRoot "ShellFolders"
New-Item -Path $sfDir -ItemType Directory -Force | Out-Null

foreach ($name in $shellFolderTargets.Keys) {
    $path = $shellFolderTargets[$name]
    $lnkFile = Join-Path $sfDir "$name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($lnkFile)
    $shortcut.TargetPath = $path
    $shortcut.Save()
}

# 2) Control Panel Items
$controlPanelItems = @{
    "ProgramsAndFeatures" = "appwiz.cpl"
    "NetworkConnections"  = "ncpa.cpl"
    "SystemProperties"    = "sysdm.cpl"
}

$cpDir = Join-Path $outputRoot "ControlPanel"
New-Item -Path $cpDir -ItemType Directory -Force | Out-Null

foreach ($name in $controlPanelItems.Keys) {
    $target = $controlPanelItems[$name]
    $lnkFile = Join-Path $cpDir "$name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($lnkFile)
    $sc.TargetPath = "C:\Windows\System32\$target"
    $sc.Save()
}

# 3) Settings URIs
$settingsURIs = @{
    "WindowsUpdate"     = "ms-settings:windowsupdate"
    "AppsFeatures"      = "ms-settings:appsfeatures"
    "NetworkStatus"     = "ms-settings:network-status"
    "DefaultApps"       = "ms-settings:defaultapps"
}

$msDir = Join-Path $outputRoot "SettingsURIs"
New-Item -Path $msDir -ItemType Directory -Force | Out-Null

foreach ($name in $settingsURIs.Keys) {
    $uri = $settingsURIs[$name]
    $lnkFile = Join-Path $msDir "$name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($lnkFile)
    $sc.TargetPath = "explorer.exe"
    $sc.Arguments = $uri
    $sc.Save()
}

Write-Host "Super God Mode Lite shortcuts created in: $outputRoot" -ForegroundColor Green
Write-Host "Done!"
