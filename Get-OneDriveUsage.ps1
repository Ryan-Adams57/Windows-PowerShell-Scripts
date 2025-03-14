If you're using OneDrive for Business, you can report on user storage.

Example: Get OneDrive for Business Usage:

# Connect to SharePoint Online (for OneDrive)
Connect-SPOService -Url https://yourtenant-admin.sharepoint.com

# Get OneDrive usage
Get-SPOSite -Template "SPSPERS" | Select-Object URL, StorageUsageCurrent, StorageQuota

This will give you a report of URL, StorageUsageCurrent, and StorageQuota for all OneDrive for Business sites.
