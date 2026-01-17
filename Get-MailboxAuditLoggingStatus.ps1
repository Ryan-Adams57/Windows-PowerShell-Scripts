Try {
    Connect-ExchangeOnline
    Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, UserPrincipalName, AuditEnabled | 
    Export-Csv -Path '.\MailboxAuditStatus.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
