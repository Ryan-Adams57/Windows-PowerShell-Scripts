Try {
    Connect-ExchangeOnline
    Get-MobileDevice -ResultSize Unlimited | Where-Object { $_.ClientType -eq 'Outlook' } | 
    Export-Csv -Path '.\OutlookMobileAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
