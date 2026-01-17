Try {
    Connect-ExchangeOnline
    Get-Mailbox -ResultSize Unlimited | Where-Object { $_.GrantSendOnBehalfTo } | 
    Select-Object DisplayName, @{N='Delegates';E={$_.GrantSendOnBehalfTo -join '; '}} | 
    Export-Csv -Path '.\SendOnBehalf.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
