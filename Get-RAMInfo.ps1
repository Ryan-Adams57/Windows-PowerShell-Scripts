# Get-RAMInfo.ps1
# Retrieves total physical memory capacity from a remote or local computer

# --- Configuration ---
$ComputerName = "<PCName>"   # e.g., "DESKTOP-001" or "." for local
# ---------------------

Write-Host "--- Physical Memory on $ComputerName ---" -ForegroundColor Cyan

# With credentials (for remote):
# $Credential = Get-Credential -Message "Enter credentials (domain\user)"
# Get-WmiObject Win32_PhysicalMemory -Credential $Credential -ComputerName $ComputerName |
#     Measure-Object -Property Capacity -Sum

# Local:
$MemResult = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
$TotalGB = [math]::Round($MemResult.Sum / 1GB, 2)
Write-Host "Total RAM: $TotalGB GB ($($MemResult.Sum) bytes)" -ForegroundColor Green
