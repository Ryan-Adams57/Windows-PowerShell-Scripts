Try {
    Connect-ExchangeOnline
    Get-SafeLinksPolicy | Select-Object Name, IsEnabled, ScanUrls | Export-Csv -Path '.\SafeLinks.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
