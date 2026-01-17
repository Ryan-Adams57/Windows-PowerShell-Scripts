Try {
    Connect-ExchangeOnline
    Get-Mailbox -ResultSize Unlimited -Archive | Select-Object DisplayName, PrimarySmtpAddress, ArchiveStatus, AutoExpandingArchiveEnabled | 
    Export-Csv -Path '.\MailboxArchives.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
