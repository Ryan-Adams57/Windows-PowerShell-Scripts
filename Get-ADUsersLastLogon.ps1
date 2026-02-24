# Get-ADUsersLastLogon.ps1
# Returns AD users who have not logged in within the last 547 days (~18 months)
# Requires AD PowerShell module (RSAT)

# Define cutoff date (547 days ago)
$When = ((Get-Date).AddDays(-547)).Date

Write-Host "--- AD Users Who Have Not Logged In Since $When ---" -ForegroundColor Cyan

Get-ADUser -Filter { LastLogonDate -lt $When } -Properties * |
    Select-Object SamAccountName, GivenName, Surname, LastLogonDate |
    Sort-Object LastLogonDate |
    Format-Table -AutoSize

# To export to CSV:
# Get-ADUser -Filter { LastLogonDate -lt $When } -Properties * |
#     Select-Object SamAccountName, GivenName, Surname, LastLogonDate |
#     Export-Csv -Path "C:\Temp\StaleADUsers.csv" -NoTypeInformation
