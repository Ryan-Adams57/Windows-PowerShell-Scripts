# Upgrade-PowerShell.ps1
# Upgrades PowerShell to the latest version using the official Microsoft installer
# Must be run as Administrator

Write-Host "--- Upgrading PowerShell via MSI ---" -ForegroundColor Cyan
Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI"
Write-Host "PowerShell upgrade initiated. Follow any prompts to complete installation." -ForegroundColor Green
