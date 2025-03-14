Get-MsolUser | Select-Object UserPrincipalName, DisplayName, IsLicensed | Export-Csv -Path "C:\Reports\Office365Users.csv" -NoTypeInformation
