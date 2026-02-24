# Get-Office365ProductInfo.ps1
# Retrieves Office 365 installation details from a remote PC
# Reference for version numbers: https://docs.microsoft.com/en-us/officeupdates/update-history-office365-proplus-by-date

# --- Configuration ---
$PCName = "<PCName>"         # e.g., "DESKTOP-001"
# ---------------------

$Credential = Get-Credential -Message "Enter domain\user credentials"

Write-Host "--- Office 365 Info on $PCName ---" -ForegroundColor Cyan

Invoke-Command -ComputerName $PCName -Credential $Credential -ScriptBlock {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\O365* |
        Select-Object DisplayName, DisplayVersion, Publisher
}
