# Connect to SharePoint Online Service
Connect-SPOService -Url "https://yourtenant-admin.sharepoint.com"

# Get Site Usage
Get-SPOSite | Select-Object URL, StorageUsageCurrent, StorageQuota
