Try {
    Connect-ExchangeOnline
    Get-QuarantineMessage -ResultSize 1000 | Select-Object ReceivedTime, SenderAddress, Subject, Reason | 
    Export-Csv -Path '.\QuarantineSummary.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
