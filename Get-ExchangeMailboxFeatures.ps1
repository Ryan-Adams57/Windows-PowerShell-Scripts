Try {
    Connect-ExchangeOnline
    Get-CASMailbox -ResultSize Unlimited | Select-Object Name, PopEnabled, ImapEnabled, OWAEnabled | 
    Export-Csv -Path '.\MailboxFeatures.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
