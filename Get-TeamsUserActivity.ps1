# Install Teams PowerShell Module
Install-Module -Name PowerShellGet -Force -AllowClobber
Install-Module -Name MicrosoftTeams

# Connect to Microsoft Teams
Connect-MicrosoftTeams

# Get Teams Activity Report
Get-TeamUserActivity -StartDate "2025-01-01" -EndDate "2025-01-31"
