Try {
    Connect-ExchangeOnline
    Get-UnifiedGroup -ResultSize Unlimited | Select-Object DisplayName, RequireSenderAuthenticationEnabled | 
    Export-Csv -Path '.\GroupExternalSenders.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
