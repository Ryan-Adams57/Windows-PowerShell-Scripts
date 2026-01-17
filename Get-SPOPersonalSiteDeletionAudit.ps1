Try {
    Get-SPODeletedSite | Where-Object { $_.Url -like '*my.sharepoint.com*' } | 
    Select-Object Url, DaysRemaining | Export-Csv -Path '.\SPODeletionAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
