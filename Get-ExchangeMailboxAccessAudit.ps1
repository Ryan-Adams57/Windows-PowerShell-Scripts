Try {
    Connect-ExchangeOnline
    $Date = (Get-Date).AddDays(-7)
    Search-MailboxAuditLog -StartDate $Date -Operations Access -ResultSize 500 | 
    Select-Object CreationTime, Operation, LogonUserDisplayName | Export-Csv -Path '.\MailboxAccess.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
