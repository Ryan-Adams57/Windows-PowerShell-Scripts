Try {
    Get-SPOExternalUser -Pagesize 100 | Export-Csv -Path '.\SPOSharingLinks.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
