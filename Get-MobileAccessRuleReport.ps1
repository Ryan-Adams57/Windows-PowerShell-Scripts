Try {
    Connect-ExchangeOnline
    Get-ActiveSyncDeviceAccessRule | Select-Object Name, QueryString, AccessLevel | Export-Csv -Path '.\MobileRules.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
