# Update-Office365.ps1
# Forces an Office 365 Click-to-Run update silently
# Must be run as Administrator

Write-Host "--- Updating Office 365 ---" -ForegroundColor Cyan

$OfficeUpdater = "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"

if (Test-Path $OfficeUpdater) {
    & $OfficeUpdater /update user displaylevel=false forceappshutdown=True
    Write-Host "Office 365 update initiated." -ForegroundColor Green
} else {
    Write-Host "OfficeC2RClient.exe not found. Office 365 may not be installed via Click-to-Run." -ForegroundColor Red
}
