# Manage-WiFiProfiles.ps1
# Export and import Wi-Fi profiles using netsh
# Must be run as Administrator

# --- Configuration ---
$ExportFolder = "<Path to existing folder>"  # e.g., "C:\Temp\WiFiProfiles"
$ImportFile   = "<Path to File Import>"      # e.g., "C:\Temp\WiFiProfiles\Wi-Fi-MyNetwork.xml"
# ---------------------

Write-Host "=== Wi-Fi Profile Manager ===" -ForegroundColor Cyan

# Export profiles (encrypted - safe for backup)
Write-Host "`n--- Exporting Wi-Fi Profiles (encrypted) to $ExportFolder ---" -ForegroundColor Yellow
netsh wlan export profile folder=$ExportFolder

# Export profiles with plaintext keys (use with caution)
# Write-Host "`n--- Exporting Wi-Fi Profiles (plaintext keys) ---" -ForegroundColor Yellow
# netsh wlan export profile key=clear folder=$ExportFolder

# Import a profile
# Write-Host "`n--- Importing Wi-Fi Profile from $ImportFile ---" -ForegroundColor Yellow
# netsh wlan add profile filename=$ImportFile

Write-Host "Done." -ForegroundColor Green
