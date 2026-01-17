Try {
    Connect-ExchangeOnline
    Get-TransportRule | Select-Object Name, State, Priority | Export-Csv -Path '.\TransportRules.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
