Example: List all users in your organization.

Get-MsolUser | Select-Object UserPrincipalName, DisplayName, IsLicensed

This script retrieves all users in your Office 365 tenant and displays their UserPrincipalName, DisplayName, and whether they are licensed or not.
