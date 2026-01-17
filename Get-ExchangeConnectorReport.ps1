Try {
    Connect-ExchangeOnline
    $In = Get-InboundConnector; $Out = Get-OutboundConnector
    ($In + $Out) | Select-Object Name, Enabled, ConnectorType | Export-Csv -Path '.\Connectors.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
