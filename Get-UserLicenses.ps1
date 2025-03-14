If you want to see what licenses are assigned to your users, you can use the following command.

Example: Get License Information:

Get-MsolUser | Select-Object UserPrincipalName, Licenses

This will show which licenses are assigned to each user in your Office 365 tenant.
