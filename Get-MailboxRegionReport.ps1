Try {
    Connect-ExchangeOnline
    Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, PreferredDataLocation | 
    Export-Csv -Path '.\MailboxRegions.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
