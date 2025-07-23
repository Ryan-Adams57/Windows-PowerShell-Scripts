# Save this as Troubleshooting.ps1

# Log file path
$logFile = "$env:USERPROFILE\Desktop\troubleshooting_log.txt"

# Ask user for the issue
$issue = Read-Host "What issue are you running into?"
Add-Content -Path $logFile -Value "`n[$(Get-Date)] Issue reported: $issue"

# Simulate "thinking"
Write-Host "Give me a second..."
Start-Sleep -Seconds 3

# Warning to save work
Write-Host "`nPlease make sure to SAVE ALL YOUR WORK before proceeding."
Write-Host "This script will restart your computer if you type 'yes'."
Write-Host "You have 30 seconds to cancel (CTRL+C) or save your files..."
Start-Sleep -Seconds 30

# Ask for confirmation
$confirm = Read-Host "`nIf you type 'yes' this will solve your problem"

# Log the user's response
Add-Content -Path $logFile -Value "[$(Get-Date)] User response: $confirm"

if ($confirm -eq "yes") {
    Write-Host "Attempting to restart the computer..."
    
    try {
        Restart-Computer -Force -ErrorAction Stop
    } catch {
        Write-Host "Restart-Computer failed. Trying shutdown.exe..."
        shutdown.exe /r /t 5 /f
    }
} else {
    Write-Host "No action taken. Please troubleshoot manually or run the script again."
}
