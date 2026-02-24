# Get-LoggedInUsers.ps1
# Shows who is currently logged in or disconnected from a system
# Uses the built-in 'query user' command

# --- Configuration ---
$ComputerName = "<computer/server name>"  # e.g., "SERVER01" or "." for local
# ---------------------

Write-Host "--- Logged-In Users on $ComputerName ---" -ForegroundColor Cyan
query user /server:$ComputerName
