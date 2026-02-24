# New-LocalAdminAccount.ps1
# Creates a local administrator account that never expires
# Must be run as Administrator

# --- Configuration ---
$AccountName = "<AccountName>"  # e.g., "LocalAdmin"
$Password    = "<Password>"     # e.g., "P@ssw0rd123" (consider prompting instead)
# ---------------------

# Prompt for password securely (recommended - uncomment to use)
# $SecurePass = Read-Host "Enter password for $AccountName" -AsSecureString
# $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
#     [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass))

Write-Host "--- Creating Local Admin Account: $AccountName ---" -ForegroundColor Cyan

C:\Windows\System32\net.exe user $AccountName $Password /Add /Expires:Never
C:\Windows\System32\net.exe LocalGroup Administrators $AccountName /Add

Write-Host "Account '$AccountName' created and added to Administrators group." -ForegroundColor Green
