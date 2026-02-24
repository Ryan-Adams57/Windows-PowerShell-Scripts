# Get-SoftwareList.ps1
# Retrieves installed software from local or remote computers

# Get all installed software on a remote computer (requires credentials)
# Replace <DomainCredential> and <ComputerName> with actual values
# $cred = Get-Credential
# Get-WmiObject -Class Win32_Product -Credential $cred -ComputerName <ComputerName>

# Get all installed software on the local machine
Get-WmiObject -Class Win32_Product | Select-Object Name, Version | Sort-Object Name | Format-Table -AutoSize

# Filter for specific software (e.g., Java)
Write-Host "`n--- Java Installations ---" -ForegroundColor Cyan
Get-WmiObject -Class Win32_Product -Filter "Name Like 'Java%'" | Select-Object Name, Version | Format-List

# Optional: Export to CSV
# Get-WmiObject -Class Win32_Product | Select-Object Name, Version | Export-Csv -Path "C:\Temp\SoftwareList.csv" -NoTypeInformation
