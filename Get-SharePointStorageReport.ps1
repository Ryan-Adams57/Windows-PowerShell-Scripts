<#
Name:           SharePoint Site Storage Audit
Description:    Exports site collection URLs and their storage consumption.
Version:        1.0
#>
Try {
    # Requires SPO Management Shell
    Get-SPOSite -Limit All | Select-Object Url, StorageUsageCurrent, StorageQuota, Owner | 
    Export-Csv -Path ".\SPOStorage.csv" -NoTypeInformation
} Catch { Write-Error "Ensure SPO module is installed: $($_.Exception.Message)" }
