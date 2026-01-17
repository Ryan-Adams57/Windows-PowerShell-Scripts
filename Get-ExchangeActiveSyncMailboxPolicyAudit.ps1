Try {
    Connect-ExchangeOnline
    Get-MobileDeviceMailboxPolicy | Select-Object Name, AlphanumericPasswordRequired | 
    Export-Csv -Path '.\MobilePolicies.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
