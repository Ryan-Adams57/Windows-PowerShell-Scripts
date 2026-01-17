Try {
    Connect-ExchangeOnline
    foreach ($M in (Get-Mailbox -ResultSize Unlimited)) {
        [PSCustomObject]@{ Primary = $M.PrimarySmtpAddress; Aliases = ($M.EmailAddresses -like 'smtp:*' -join '; ') }
    } | Export-Csv -Path '.\MailboxAliases.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
