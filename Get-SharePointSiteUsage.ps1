You can retrieve information about the usage of SharePoint Online sites.

Example: Get SharePoint Site Usage:

# Connect to SharePoint Online Service
Connect-SPOService -Url "https://yourtenant-admin.sharepoint.com"

# Get Site Usage
Get-SPOSite | Select-Object URL, StorageUsageCurrent, StorageQuota

This provides a report on SharePoint site usage, including storage usage and storage quota.

