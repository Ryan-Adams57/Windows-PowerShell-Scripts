Try {
    Connect-ExchangeOnline
    Get-TransportRule | Where-Object { $_.SetSCL -eq -1 -or $_.RedirectMessageTo } | 
    Select-Object Name, SetSCL, RedirectMessageTo | Export-Csv -Path '.\RiskTransportRules.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
