Try {
    Connect-ExchangeOnline
    Get-Mailbox -RecipientTypeDetails RoomMailbox, EquipmentMailbox | ForEach-Object { Get-CalendarProcessing -Identity $_.UserPrincipalName } | 
    Select-Object Identity, AutomateProcessing, AllowConflicts | Export-Csv -Path '.\ResourcePolicies.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
