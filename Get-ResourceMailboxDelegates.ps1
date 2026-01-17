Try {
    Connect-ExchangeOnline
    Get-Mailbox -RecipientTypeDetails RoomMailbox, EquipmentMailbox | 
    ForEach-Object { $C = Get-CalendarProcessing -Identity $_.UserPrincipalName; [PSCustomObject]@{ Resource = $_.DisplayName; Delegates = ($C.ResourceDelegates -join '; ') } } | 
    Export-Csv -Path '.\ResourceDelegates.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
