Try {
    Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '*-my.sharepoint.com/personal/*'" | 
    Select-Object Url, Owner, StorageQuota | Export-Csv -Path '.\OneDriveSites.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
