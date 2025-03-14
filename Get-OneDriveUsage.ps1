# Connect to SharePoint Online (for OneDrive)
Connect-SPOService -Url https://yourtenant-admin.sharepoint.com

# Get OneDrive usage
Get-SPOSite -Template "SPSPERS" | Select-Object URL, StorageUsageCurrent, StorageQuota
