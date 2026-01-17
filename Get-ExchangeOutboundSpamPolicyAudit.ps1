Try {
    Connect-ExchangeOnline
    Get-HostedOutboundSpamFilterPolicy | Select-Object Name, RecipientLimitExternalPerHour | 
    Export-Csv -Path '.\OutboundSpamPolicy.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
