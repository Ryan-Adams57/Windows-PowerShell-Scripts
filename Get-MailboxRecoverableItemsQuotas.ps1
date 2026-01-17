Try {
    Connect-ExchangeOnline
    Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, RecoverableItemsQuota, RecoverableItemsWarningQuota | 
    Export-Csv -Path '.\RecoverableQuotas.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
