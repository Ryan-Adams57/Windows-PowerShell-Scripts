# Check-WSUSUpdate.ps1
# Triggers a WSUS detection cycle on the local machine
# No admin rights required for this specific command

Write-Host "--- Triggering WSUS Detection Cycle ---" -ForegroundColor Cyan
(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
Write-Host "WSUS detection triggered. Check Windows Update for pending updates." -ForegroundColor Green
