# Run-WindowsUpdate.ps1
# Installs Windows Updates using the PSWindowsUpdate module
# Must be run as Administrator

Write-Host "--- Installing PSWindowsUpdate Module ---" -ForegroundColor Cyan

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module PSWindowsUpdate -Force
Import-Module PSWindowsUpdate

# Enable remote Windows Update management (optional)
# Enable-WURemoting

Write-Host "--- Checking and Installing Windows Updates ---" -ForegroundColor Cyan
Get-WindowsUpdate -AcceptAll -Install -AutoReboot
