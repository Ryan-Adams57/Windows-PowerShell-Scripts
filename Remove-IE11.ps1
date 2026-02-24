# Remove-IE11.ps1
# Removes Internet Explorer 11 from Windows
# Must be run as Administrator
# A reboot will be required after completion

Write-Host "--- Removing Internet Explorer 11 ---" -ForegroundColor Cyan
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

Write-Host "IE11 has been disabled. Please reboot the computer to complete removal." -ForegroundColor Green
