Try {
    Connect-ExchangeOnline
    Get-MailboxStatistics -All | Select-Object DisplayName, TotalDeletedItemSize | Export-Csv -Path '.\DeletedItems.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
