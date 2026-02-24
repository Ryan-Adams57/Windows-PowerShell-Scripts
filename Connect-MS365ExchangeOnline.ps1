# Connect-MS365ExchangeOnline.ps1
# MS365 / Exchange Online management commands
# Must be run as Administrator or with appropriate M365 admin rights
# Thanks to @padiscgolfer for the module tip

Write-Host "=== MS365 Exchange Online Management ===" -ForegroundColor Cyan

# Install the Exchange Online Management module (run once)
# Install-Module ExchangeOnlineManagement -Force

# Connect to Exchange Online (opens browser for modern auth)
Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
Connect-ExchangeOnline

# --- Mailbox Operations ---

# Force managed folder processing on a specific mailbox
# Replace <email account> with the target email address
# Start-ManagedFolderAssistant -Identity "<user@domain.com>"

# Get inbox rules (including hidden) for a mailbox
# Get-InboxRule -Mailbox "<user@domain.com>"

Write-Host "`nConnected. Use Start-ManagedFolderAssistant and Get-InboxRule as needed." -ForegroundColor Green
