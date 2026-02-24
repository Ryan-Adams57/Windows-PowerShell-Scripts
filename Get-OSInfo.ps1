# Get-OSInfo.ps1
# Retrieves Operating System information from the local machine

# Full OS object
Get-WmiObject -Class Win32_OperatingSystem

# Selected OS details
Write-Host "`n--- OS Caption and Version ---" -ForegroundColor Cyan
Get-WmiObject -Class Win32_OperatingSystem | Select-Object Caption, Version

# Get uptime (PowerShell v5.1)
Write-Host "`n--- System Uptime ---" -ForegroundColor Cyan
(Get-ComputerInfo).OsUptime

# Get detailed computer info
Write-Host "`n--- Computer Info Summary ---" -ForegroundColor Cyan
Get-ComputerInfo | Select-Object CSName, WindowsProductName, WindowsVersion, OSVersion, OSHardwareAbstractionLayer
