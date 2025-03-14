For all of the above scripts, you can export the data to a CSV file for further analysis or reporting purposes.

Example: Export to CSV:

Get-MsolUser | Select-Object UserPrincipalName, DisplayName, IsLicensed | Export-Csv -Path "C:\Reports\Office365Users.csv" -NoTypeInformation

This script exports a list of all users (including their UserPrincipalName, DisplayName, and IsLicensed) to a CSV file located at C:\Reports\Office365Users.csv.
