# Manage-AppxPackages.ps1
# Find, remove, and re-register AppX / provisioned packages
# Must be run as Administrator

# --- Configuration ---
$AppName = "<name>"  # e.g., "Teams" or "Xbox"
# ---------------------

Write-Host "=== AppX Package Management ===" -ForegroundColor Cyan

# Find a provisioned package by name
Write-Host "`n--- Searching for provisioned package: $AppName ---" -ForegroundColor Yellow
Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$AppName*" } | Select-Object PackageName

# Remove a provisioned package (replace <PackageName> with full name from above)
# Remove-AppxProvisionedPackage -Online -PackageName "<FullPackageName>"

# Re-register all AppX packages for all users (useful for fixing broken Store apps)
Write-Host "`n--- Re-registering all AppX packages ---" -ForegroundColor Yellow
Get-AppxPackage -AllUsers * | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
}

# Re-register Microsoft Store specifically
Write-Host "`n--- Re-registering Microsoft Store ---" -ForegroundColor Yellow
Get-AppxPackage Microsoft.WindowsStore | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}

Write-Host "Done." -ForegroundColor Green
