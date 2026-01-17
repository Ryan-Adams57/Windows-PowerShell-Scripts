Try {
    Connect-ExchangeOnline
    Get-Mailbox -PublicFolder | ForEach-Object { Get-MailboxStatistics -Identity $_.Guid.ToString() } | 
    Select-Object DisplayName, TotalItemSize, ItemCount | Export-Csv -Path '.\PublicFolderStats.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
