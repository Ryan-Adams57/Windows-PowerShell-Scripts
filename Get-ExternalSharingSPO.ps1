Try {
    $Sites = Get-SPOSite -Limit All
    $Sites | Select-Object Title, Url, SharingCapability, Owner | Export-Csv -Path '.\SPOExternalSharing.csv' -NoTypeInformation
} Catch { Write-Error "SPO Shell Required: $($_.Exception.Message)" }
